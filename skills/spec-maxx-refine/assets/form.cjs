'use strict';

function formatResponse(data, selections) {
  const answers = data.questions.flatMap((question, index) => {
    const selection = selections[index];
    const text = selection?.text ?? '';
    const documentManuallyEdited = selection?.documentManuallyEdited === true;
    let answer = null;
    if (selection && /^\d+$/.test(selection.value) && question.choices[Number(selection.value)] !== undefined) {
      answer = question.choices[Number(selection.value)];
    }
    if (answer === null && selection?.value !== 'other' && !text.trim() && !documentManuallyEdited) return [];
    return [{ id: question.id, answer, text, documentManuallyEdited }];
  });
  return 'Please use these answers to suggest revisions to the specification and review remaining ambiguity. ' +
    'Please leave omitted questions unresolved and avoid redundant or inferable statements. ' +
    'Please re-read passages marked as manually edited before suggesting further revisions. ' +
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
    const issue = element('td');
    issue.append(element('div', question.issue));
    const category = element('div', question.category);
    category.className = 'category';
    issue.append(category);
    row.append(id, element('td', question.citations), issue);
    const cell = element('td');
    const group = element('fieldset');
    group.append(element('legend', question.question));
    const radios = [];
    const choices = question.choices.map((label, value) => ({ label, value: String(value) }));
    choices.push({ label: 'Other', value: 'other' });
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
    custom.id = `text-${index}`;
    custom.rows = 2;
    const customLabel = element('label', `Your answer or notes for ${question.id}`);
    customLabel.htmlFor = custom.id;
    customLabel.className = 'custom-label';
    group.append(customLabel, custom);
    const edited = element('input');
    edited.type = 'checkbox';
    edited.id = `edited-${index}`;
    const editedLabel = element('label');
    editedLabel.className = 'choice';
    editedLabel.append(edited, element('span', 'document manually edited'));
    group.append(editedLabel);
    cell.append(group);
    row.append(cell);
    rows.append(row);
    return { radios, custom, edited };
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
      output.value = formatResponse(data, controls.map(({ radios, custom, edited }) => ({
        value: radios.find(radio => radio.checked)?.value,
        text: custom.value,
        documentManuallyEdited: edited.checked
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
