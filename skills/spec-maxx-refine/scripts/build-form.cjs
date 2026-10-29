#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');

function validateInput(data) {
  function object(value, keys, label) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${label} must be an object.`);
    for (const key of Object.keys(value)) {
      if (!keys.includes(key)) throw new Error(`${label}.${key} is not supported.`);
    }
  }
  function text(value, label) {
    if (typeof value !== 'string' || !value.trim()) throw new Error(`${label} must be a nonempty string.`);
  }
  object(data, ['schemaVersion', 'spec', 'questions'], 'input');
  if (data.schemaVersion !== 1) throw new Error('schemaVersion must be 1.');
  text(data.spec, 'spec');
  if (!Array.isArray(data.questions)) throw new Error('questions must be an array.');
  const ids = new Set();
  data.questions.forEach((question, index) => {
    const label = `questions[${index}]`;
    object(question, ['id', 'category', 'passage', 'question', 'choices'], label);
    for (const key of ['id', 'category', 'passage', 'question']) text(question[key], `${label}.${key}`);
    if (ids.has(question.id)) throw new Error(`${label}.id must be unique.`);
    ids.add(question.id);
    if (!Array.isArray(question.choices) || question.choices.length < 2) throw new Error(`${label}.choices must contain at least two answers.`);
    const choices = new Set();
    question.choices.forEach((choice, choiceIndex) => {
      text(choice, `${label}.choices[${choiceIndex}]`);
      const key = choice.trim().toLowerCase();
      if (['other', 'defer decision'].includes(key)) throw new Error(`${label}: Other and Defer decision are added automatically.`);
      if (choices.has(key)) throw new Error(`${label}.choices must be distinct.`);
      choices.add(key);
    });
  });
  return data;
}

function buildHtml(data) {
  validateInput(data);
  const assets = path.join(__dirname, '..', 'assets');
  const template = fs.readFileSync(path.join(assets, 'form.html'), 'utf8');
  const runtime = fs.readFileSync(path.join(assets, 'form.cjs'), 'utf8');
  // Escaping '<' prevents untrusted strings from ending the JSON script element.
  const json = JSON.stringify(data).replace(/</g, '\\u003c').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
  return template.replace(/__FORM_DATA__|__FORM_RUNTIME__/g, token => token === '__FORM_DATA__' ? json : runtime);
}

if (require.main === module) {
  try {
    const args = process.argv.slice(2);
    if (args.length === 1 && args[0] === '--help') {
      console.log('Usage: node build-form.cjs INPUT.json OUTPUT.html');
    } else {
      if (args.length !== 2) throw new Error('Usage: node build-form.cjs INPUT.json OUTPUT.html');
      const [input, output] = args;
      if (!/\.html?$/i.test(output)) throw new Error('The output path must end in .html or .htm.');
      const data = JSON.parse(fs.readFileSync(input, 'utf8').replace(/^\uFEFF/, ''));
      const html = buildHtml(data);
      fs.writeFileSync(output, html, { encoding: 'utf8', flag: 'wx' });
      console.log(`Created ${path.resolve(output)} (${data.questions.length} questions).`);
    }
  } catch (error) {
    console.error(`Form generation failed: ${error.message}`);
    process.exitCode = 1;
  }
}
module.exports = { validateInput, buildHtml };
