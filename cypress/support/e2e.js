// ***********************************************************
// Este arquivo é processado e carregado automaticamente antes
// dos arquivos de teste.
// Use-o para definir comportamentos globais e registrar plugins.
// ***********************************************************

import 'cypress-terminal-report/src/installLogsCollector';
import 'cypress-mochawesome-reporter/register';
import 'cypress-downloadfile/lib/downloadFileCommand';
import './commands';

// Captura screenshot automaticamente quando o teste falha
Cypress.on('fail', (error, runnable) => {
  const testName = runnable.parent.title + ' -- ' + runnable.title;
  const screenshotFileName = testName.replace(/[:\/]/g, ' ');
  cy.screenshot(screenshotFileName, { capture: 'runner' });
  throw error; // mantém o comportamento padrão do Cypress
});
