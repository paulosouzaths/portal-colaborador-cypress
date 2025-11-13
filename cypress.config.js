const { defineConfig } = require('cypress');
const installLogsPrinter = require('cypress-terminal-report/src/installLogsPrinter');

module.exports = defineConfig({
  e2e: {
    baseUrl: 'https://www1.portaldaseguranca.sp.gov.br:3200',
    supportFile: 'cypress/support/e2e.js',
    video: false,

    reporter: 'cypress-mochawesome-reporter',
    reporterOptions: {
      reportDir: 'cypress/reports/html',
      reportFilename: 'mochawesome',
      overwrite: true,
      html: true,
      json: true,
      saveJson: true,
      embeddedScreenshots: true,
      inlineAssets: true,
      showHooks: 'failed',
      code: false,
      sort: 'suite',
      charts: true,
      reportTitle: 'Portal do Colaborador - Relatório de Testes',
      quiet: true,
    },

    setupNodeEvents(on, config) {
      console.log('🧠 Carregando Mochawesome Reporter...');
      require('cypress-mochawesome-reporter/plugin')(on);
      console.log('✅ Mochawesome pronto.');

      installLogsPrinter(on, {
        printLogsToConsole: 'always',
        printLogsToFile: 'onFail',
        outputRoot: 'cypress/logs',
        outputTarget: {
          'out.txt': 'txt',
          'out.json': 'json',
        },
        includeSuccessfulHookLogs: false,
        defaultTrimLength: 300,
      });

      return config;
    },
  },
});
