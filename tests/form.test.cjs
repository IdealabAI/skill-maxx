'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { spawnSync } = require('node:child_process');
const skill = path.resolve(__dirname, '../skills/spec-maxx-refine');
const { validateInput, buildHtml } = require(path.join(skill, 'scripts/build-form.cjs'));
const { formatResponse } = require(path.join(skill, 'assets/form.cjs'));
const example = JSON.parse(fs.readFileSync(path.join(skill, 'references/example-questions.json'), 'utf8'));
const fresh = () => structuredClone(example);

function temporary(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'spec-maxx-form-'));
  t.after(() => {
    assert.equal(path.dirname(path.resolve(root)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(root).startsWith('spec-maxx-form-'));
    fs.rmSync(root, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  });
  return root;
}

test('validation accepts the documented input and rejects unusable question data', () => {
  assert.equal(validateInput(example), example);
  for (const mutate of [
    d => { d.spec = ' '; },
    d => { d.questions = {}; },
    d => { d.questions.push(structuredClone(d.questions[0])); },
    d => { d.questions[0].question = ''; },
    d => { delete d.questions[0].citations; },
    d => { d.questions[0].issue = ' '; },
    d => { d.questions[0].choices = ['Only one']; },
    d => { d.questions[0].choices = ['Same', ' same ']; },
    d => { d.questions[0].choices = ['Other', 'Something']; },
    d => { d.questions[0].choices = ['Something', 42]; },
    d => { d.questions[0].typo = 'Ignored data'; },
    d => { d.unexpected = true; }
  ]) {
    const data = fresh();
    mutate(data);
    assert.throws(() => validateInput(data));
  }
  assert.throws(() => validateInput(null));
  assert.doesNotThrow(() => buildHtml({ ...example, questions: [] }));
});

test('embedded JSON round-trips script terminators, Unicode, and replacement tokens', () => {
  const data = fresh();
  data.spec = '</script><script>globalThis.injected = true</script> & " $& __FORM_RUNTIME__ \u2028 café';
  data.questions[0].citations = '<img src=x onerror=alert(1)>';
  const html = buildHtml(data);
  const embedded = html.match(/<script type="application\/json" id="form-data">([\s\S]*?)<\/script>/)[1];
  assert.deepEqual(JSON.parse(embedded), data);
  assert.ok(!embedded.includes('<'));
  assert.equal((html.match(/<script[ >]/g) || []).length, 2);
  assert.equal(buildHtml(data), html);
});

test('answer export preserves text and independent manual edits while omitting untouched questions', () => {
  const data = fresh();
  data.questions = Array.from({ length: 9 }, (_, i) => ({ ...data.questions[0], id: `Q${i + 1}` }));
  const response = formatResponse(data, [
    { value: '1', text: ' Notes with a choice ', documentManuallyEdited: true },
    { value: 'other', text: ' Custom\nanswer ' },
    { documentManuallyEdited: true },
    { text: 'Text without a choice' },
    { value: '0' },
    { value: 'other' },
    { text: ' \n ' },
    { documentManuallyEdited: false }
  ]);
  const result = JSON.parse(response.slice(response.indexOf('\n\n') + 2));
  assert.equal(result.spec, data.spec);
  assert.deepEqual(result.answers, [
    { id: 'Q1', answer: data.questions[0].choices[1], text: ' Notes with a choice ', documentManuallyEdited: true },
    { id: 'Q2', answer: null, text: ' Custom\nanswer ', documentManuallyEdited: false },
    { id: 'Q3', answer: null, text: '', documentManuallyEdited: true },
    { id: 'Q4', answer: null, text: 'Text without a choice', documentManuallyEdited: false },
    { id: 'Q5', answer: data.questions[4].choices[0], text: '', documentManuallyEdited: false },
    { id: 'Q6', answer: null, text: '', documentManuallyEdited: false }
  ]);
  const untouched = formatResponse(data, []);
  assert.deepEqual(JSON.parse(untouched.slice(untouched.indexOf('\n\n') + 2)).answers, []);
});

test('copied skill builds from another directory and refuses invalid input or overwrites', t => {
  const root = temporary(t);
  const installed = path.join(root, 'installed skill');
  fs.cpSync(skill, installed, { recursive: true });
  const input = path.join(root, 'questions.json');
  const output = path.join(root, 'review form.html');
  const script = path.join(installed, 'scripts/build-form.cjs');
  const run = (...args) => spawnSync(process.execPath, [script, ...args], { cwd: root, encoding: 'utf8' });
  fs.writeFileSync(input, '\uFEFF' + JSON.stringify(example));
  const built = run(input, output);
  assert.equal(built.status, 0, built.stderr);
  assert.equal(fs.readFileSync(output, 'utf8'), buildHtml(example));
  assert.notEqual(run(input, output).status, 0);
  assert.equal(fs.readFileSync(output, 'utf8'), buildHtml(example));
  fs.writeFileSync(input, '{broken');
  assert.notEqual(run(input, path.join(root, 'invalid.html')).status, 0);
  assert.ok(!fs.existsSync(path.join(root, 'invalid.html')));
  assert.equal(run('--help').status, 0);
  assert.notEqual(run().status, 0);
});

const browser = process.env.FORM_TEST_BROWSER || [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome', '/usr/bin/chromium'
].find(candidate => fs.existsSync(candidate));

test('browser separates citations and issues and exports choices, text, and independent manual edits',
  { skip: browser ? false : 'Chrome or Edge is unavailable; set FORM_TEST_BROWSER to enable this check.' }, t => {
    const root = temporary(t);
    const data = fresh();
    data.spec = '</script><script>globalThis.injected=true</script>';
    data.questions = Array.from({ length: 5 }, (_, i) => ({ ...data.questions[0], id: `Q${i + 1}` }));
    data.questions[0].citations = '<img src=x onerror="globalThis.injected=true">';
    const checks = function () {
      const result = document.createElement('pre');
      result.id = 'test-result';
      function check(condition, message) { if (!condition) throw new Error(message); }
      try {
        check(!globalThis.injected && !document.querySelector('img'), 'Untrusted HTML executed.');
        check(document.querySelectorAll('#questions tr').length === 5, 'Questions are missing.');
        check(document.querySelectorAll('input:checked').length === 0, 'An answer was preselected.');
        const data = JSON.parse(document.getElementById('form-data').textContent);
        const cells = document.querySelector('#questions tr').children;
        check(cells.length === 4, 'The column count is wrong.');
        check(cells[1].textContent === data.questions[0].citations, 'Citations are not separate.');
        check(cells[2].firstChild.textContent === data.questions[0].issue, 'The issue is missing.');
        check(cells[2].lastChild.textContent === data.questions[0].category, 'The category is not below the issue.');
        check(!document.querySelector('input[value="defer"]'), 'The removed option remains.');
        check([...document.querySelectorAll('#questions textarea')].every(node => !node.disabled && !node.required), 'Text is not freely editable.');
        const radio = (index, value) => document.querySelector(`input[name="question-${index}"][value="${value}"]`);
        radio(0, '0').click();
        radio(0, '1').click();
        check(!radio(0, '0').checked && radio(0, '1').checked, 'Choices are not exclusive.');
        const notes = document.getElementById('text-0');
        notes.value = 'Notes accompanying a predefined choice';
        document.getElementById('edited-0').click();
        radio(1, 'other').click();
        const other = document.getElementById('text-1');
        other.value = 'Custom answer <b>as text</b>';
        other.dispatchEvent(new Event('input', { bubbles: true }));
        document.getElementById('edited-2').click();
        document.getElementById('text-3').value = 'Text without a selection';
        document.querySelector('button').click();
        const output = document.getElementById('output');
        const parsed = JSON.parse(output.value.split('\n\n').slice(1).join('\n\n'));
        check(parsed.answers.map(a => a.id).join(',') === 'Q1,Q2,Q3,Q4', 'Addressed questions were lost or untouched questions were included.');
        check(parsed.answers[0].answer === data.questions[0].choices[1] && parsed.answers[0].text === notes.value && parsed.answers[0].documentManuallyEdited, 'Combined controls were lost.');
        check(parsed.answers[1].text === other.value, 'Custom text was lost.');
        check(parsed.answers[2].answer === null && parsed.answers[2].text === '' && parsed.answers[2].documentManuallyEdited, 'The standalone checkbox was lost.');
        check(parsed.answers[3].answer === null && parsed.answers[3].text === 'Text without a selection', 'Standalone text was lost.');
        check(output.readOnly, 'The output is editable.');
        check(document.activeElement === output, 'The output was not focused.');
        radio(1, '0').click();
        check(!other.disabled && !other.required, 'Text became unavailable after changing choices.');
        check(output.value === '', 'Stale output was retained after a change.');
        document.querySelector('button').click();
        const updated = JSON.parse(output.value.split('\n\n').slice(1).join('\n\n'));
        check(updated.answers[1].text === other.value && updated.answers[1].answer === data.questions[1].choices[0], 'Changing choices lost text.');
        document.getElementById('edited-2').click();
        check(output.value === '', 'Checkbox edits retained stale output.');
        document.querySelector('button').click();
        check(!JSON.parse(output.value.split('\n\n').slice(1).join('\n\n')).answers.some(a => a.id === 'Q3'), 'An unchecked, otherwise untouched question remains.');
        notes.value += ' Updated';
        notes.dispatchEvent(new Event('input', { bubbles: true }));
        check(output.value === '', 'Text edits retained stale output.');
        result.textContent = 'PASS';
      } catch (error) { result.textContent = `FAIL: ${error.stack}`; }
      document.body.append(result);
    };
    const html = buildHtml(data).replace('</body>', () => `<script>(${checks.toString()})();</script></body>`);
    const file = path.join(root, 'browser-test.html');
    fs.writeFileSync(file, html);
    const run = spawnSync(browser, [
      '--headless', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
      `--user-data-dir=${path.join(root, 'browser-profile')}`, '--dump-dom', pathToFileURL(file).href
    ], { encoding: 'utf8', timeout: 25000, maxBuffer: 4 * 1024 * 1024, windowsHide: true });
    assert.ifError(run.error);
    assert.equal(run.status, 0, run.stderr);
    const result = run.stdout.match(/<pre id="test-result">([\s\S]*?)<\/pre>/);
    assert.ok(result, `The browser did not report a test result: ${run.stderr}`);
    assert.equal(result[1], 'PASS');
  });
