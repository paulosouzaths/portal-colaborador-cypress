const { defineConfig } = require('cypress');
const mochawesome = require('cypress-mochawesome-reporter/plugin');

module.exports = defineConfig({
  e2e: {
    baseUrl: 'https://www1.portaldaseguranca.sp.gov.br:3200',
    video: false, // evita salvar vídeos desnecessários
    reporter: 'cypress-mochawesome-reporter',
    reporterOptions: {
      reportDir: 'cypress/reports/html',
      overwrite: true, // sobrescreve relatórios antigos
      html: true,
      json: true,
      embeddedScreenshots: true, // 🔹 inclui prints dentro do HTML
      inlineAssets: true,        // 🔹 mantém CSS/JS dentro do HTML
      charts: true,              // adiciona gráficos de sucesso/falha
      reportPageTitle: 'Portal do Colaborador - Validação de Câmeras'
    },
    setupNodeEvents(on, config) {
      mochawesome(on); // 🔹 registra o plugin corretamente
    },
  },
});
