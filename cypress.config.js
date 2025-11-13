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
      showHooks: 'failed',       // só mostra hooks que falharam
      code: false,
      sort: 'suite',             // mantém a ordem real dos testes
      charts: true,              // adiciona gráfico no topo
      reportTitle: 'Portal do Colaborador - Relatório de Testes',
      quiet: true,
    },

    setupNodeEvents(on, config) {
      console.log('🧠 Carregando Mochawesome Reporter...');
      require('cypress-mochawesome-reporter/plugin')(on);
      console.log('✅ Mochawesome pronto.');

      // Terminal report (para logs limpos)
      installLogsPrinter(on, {
        printLogsToConsole: 'always',
        printLogsToFile: 'onFail',
        outputRoot: 'cypress/logs',
        outputTarget: {
          'out.txt': 'txt',
          'out.json': 'json'
        },
        includeSuccessfulHookLogs: false,
        defaultTrimLength: 300
      });

      return config;
    },
  },
});
