'use strict';

const { detectGitEnv, detectProject } = require('./detect');
const { Scaffold } = require('./scaffold');

module.exports = { detectGitEnv, detectProject, Scaffold };
