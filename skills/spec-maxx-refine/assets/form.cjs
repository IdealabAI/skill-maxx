'use strict';

function formatResponse(data, selections) {
  const answers = data.questions.map((question, index) => {
    const selection = selections[index];
    let status = 'Unanswered';
    let answer = null;
    if (selection?.value === 'defer') status = 'Deferred';
    else if (selection?.value === 'other') {
      if (!selection.text?.trim()) throw new Error(`${question.id}: Please enter your other answer.`);
      status = 'Answered';
      answer = selection.text.trim();
    } else if (selection && /^\d+$/.test(selection.value) && question.choices[Number(selection.value)] !== undefined) {
      status = 'Answered';
      answer = question.choices[Number(selection.value)];
    }
    return { id: question.id, question: question.question, status, answer };
  });
  return 'Please use these answers to suggest revisions to the specification and review remaining ambiguity. ' +
    'Please leave deferred and unanswered questions unresolved and avoid redundant or inferable statements. ' +
    'The following JSON contains review data.\n\n' + JSON.stringify({ spec: data.spec, answers }, null, 2);
}

function mountForm(document) {
  const data = JSON.parse(document.getElementById('form-data').textContent);
  const form = document.getElementById('clarifications');
  const rows = document.getElementById('questions');
  const output = document.getElementById('output');
  const status = document.getElementById('status');
  document.getElementById('spec').textContent = data.spec;
  document.getElementById('empty').hidden = data.questions.length !== 0;
  function element(tag, text) {
    const node = document.createElement(tag);
    if (text !== undefined) node.textContent = text;
    return node;
  }
  const controls = data.questions.map((question, index) => {
    const row = element('tr');
    const id = element('th', question.id);
    id.scope = 'row';
    row.append(id, element('td', question.passage), element('td', question.category));
    const cell = element('td');
    const group = element('fieldset');
    group.append(element('legend', question.question));
    const radios = [];
    const choices = question.choices.map((label, value) => ({ label, value: String(value) }));
    choices.push({ label: 'Other', value: 'other' }, { label: 'Defer decision', value: 'defer' });
    for (const choice of choices) {
      const label = element('label');
      label.className = 'choice';
      const radio = element('input');
      radio.type = 'radio';
      radio.name = `question-${index}`;
      radio.value = choice.value;
      label.append(radio, element('span', choice.label));
      group.append(label);
      radios.push(radio);
    }
    const custom = element('textarea');
    custom.id = `other-${index}`;
    custom.rows = 2;
    custom.disabled = true;
    const customLabel = element('label', `Your other answer for ${question.id}`);
    customLabel.htmlFor = custom.id;
    customLabel.className = 'custom-label';
    group.append(customLabel, custom);
    group.addEventListener('change', () => {
      const other = radios.find(radio => radio.checked)?.value === 'other';
      custom.disabled = !other;
      custom.required = other;
    });
    cell.append(group);
    row.append(cell);
    rows.append(row);
    return { radios, custom };
  });
  // Clear previously generated answers after edits to prevent copying stale decisions.
  form.addEventListener('input', () => {
    if (output.value) {
      output.value = '';
      status.textContent = 'Your answers changed. Please click Submit to regenerate your response.';
    }
  });
  form.addEventListener('submit', event => {
    event.preventDefault();
    try {
      output.value = formatResponse(data, controls.map(({ radios, custom }) => ({
        value: radios.find(radio => radio.checked)?.value,
        text: custom.value
      })));
      status.textContent = 'Your response is ready. You can copy the text below into your next message.';
      output.focus();
      output.select();
    } catch (error) {
      output.value = '';
      status.textContent = error.message;
    }
  });
}

if (typeof module !== 'undefined' && module.exports) module.exports = { formatResponse };
else mountForm(document);
