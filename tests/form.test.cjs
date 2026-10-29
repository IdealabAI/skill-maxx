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
    d => { d.schemaVersion = 2; },
    d => { d.spec = ' '; },
    d => { d.questions = {}; },
    d => { d.questions.push(structuredClone(d.questions[0])); },
    d => { d.questions[0].question = ''; },
    d => { delete d.questions[0].passage; },
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
  data.questions[0].passage = '<img src=x onerror=alert(1)>';
  const html = buildHtml(data);
  const embedded = html.match(/<script type="application\/json" id="form-data">([\s\S]*?)<\/script>/)[1];
  assert.deepEqual(JSON.parse(embedded), data);
  assert.ok(!embedded.includes('<'));
  assert.equal((html.match(/<script[ >]/g) || []).length, 2);
  assert.equal(buildHtml(data), html);
});

test('answer export preserves full answers and distinguishes unresolved decisions', () => {
  const data = fresh();
  data.questions = Array.from({ length: 4 }, (_, i) => ({ ...data.questions[0], id: `Q${i + 1}` }));
  const response = formatResponse(data, [{ value: '1' }, { value: 'other', text: ' Custom\nanswer ' }, { value: 'defer' }]);
  const result = JSON.parse(response.slice(response.indexOf('\n\n') + 2));
  assert.equal(result.spec, data.spec);
  assert.deepEqual(result.answers.map(a => a.status), ['Answered', 'Answered', 'Deferred', 'Unanswered']);
  assert.equal(result.answers[0].answer, data.questions[0].choices[1]);
  assert.equal(result.answers[1].answer, 'Custom\nanswer');
  assert.equal(result.answers[2].answer, null);
  assert.equal(result.answers[3].question, data.questions[3].question);
  assert.throws(() => formatResponse(example, [{ value: 'other', text: ' ' }]), /other answer/);
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

test('browser renders text safely and submits selected, other, deferred, and unanswered choices',
  { skip: browser ? false : 'Chrome or Edge is unavailable; set FORM_TEST_BROWSER to enable this check.' }, t => {
    const root = temporary(t);
    const data = fresh();
    data.spec = '</script><script>globalThis.injected=true</script>';
    data.questions = Array.from({ length: 4 }, (_, i) => ({ ...data.questions[0], id: `Q${i + 1}` }));
    data.questions[0].passage = '<img src=x onerror="globalThis.injected=true">';
    const checks = function () {
      const result = document.createElement('pre');
      result.id = 'test-result';
      function check(condition, message) { if (!condition) throw new Error(message); }
      try {
        check(!globalThis.injected && !document.querySelector('img'), 'Untrusted HTML executed.');
        check(document.querySelectorAll('#questions tr').length === 4, 'Questions are missing.');
        check(document.querySelectorAll('input:checked').length === 0, 'An answer was preselected.');
        const radio = (index, value) => document.querySelector(`input[name="question-${index}"][value="${value}"]`);
        radio(0, '0').click();
        radio(0, '1').click();
        check(!radio(0, '0').checked && radio(0, '1').checked, 'Choices are not exclusive.');
        radio(1, 'other').click();
        const other = document.getElementById('other-1');
        check(!other.disabled && other.required, 'Other answer is unavailable.');
        document.querySelector('button').click();
        check(document.getElementById('output').value === '', 'Empty Other answer was accepted.');
        other.value = 'Custom answer <b>as text</b>';
        other.dispatchEvent(new Event('input', { bubbles: true }));
        radio(2, 'defer').click();
        document.querySelector('button').click();
        const output = document.getElementById('output');
        const parsed = JSON.parse(output.value.split('\n\n').slice(1).join('\n\n'));
        check(parsed.answers.map(a => a.status).join(',') === 'Answered,Answered,Deferred,Unanswered', 'Answer statuses are wrong.');
        check(parsed.answers[1].answer === other.value, 'Custom text was lost.');
        check(output.readOnly, 'The output is editable.');
        check(document.activeElement === output, 'The output was not focused.');
        radio(1, '0').click();
        check(other.disabled && !other.required, 'Custom validation remains active.');
        check(output.value === '', 'Stale output was retained after a change.');
        document.querySelector('button').click();
        check(output.value.includes('Answered'), 'The response did not regenerate.');
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
