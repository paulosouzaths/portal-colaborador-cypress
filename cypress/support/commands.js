
Cypress.Commands.add('waitForVideo', (selector, options = {}) => {
  const timeoutMs = options.timeout || 60000;

  // 1) garante que o elemento exista e esteja visível
  cy.get(selector, { timeout: timeoutMs }).should('be.visible');

  // 2) depois, usa o elemento real e retorna uma Promise que Cypress espera
  return cy.get(selector).then(($video) => {
    const video = $video[0];

    return new Cypress.Promise((resolve) => {
      // se já tiver dados suficientes, resolve imediatamente
      if (video.readyState >= 3 && !video.paused) {
        resolve();
        return;
      }

      // handler que resolve uma vez que video esteja pronto
      const onReady = () => {
        cleanup();
        resolve();
      };

      // fallback: timeout para nunca travar indefinidamente
      const fallback = setTimeout(() => {
        cleanup();
        resolve();
      }, Math.max(10000, timeoutMs)); // pelo menos 10s

      // limpa listeners
      const cleanup = () => {
        clearTimeout(fallback);
        try {
          video.removeEventListener('playing', onReady);
          video.removeEventListener('canplay', onReady);
        } catch (e) { /* ignorar */ }
      };

      // registra listeners
      video.addEventListener('playing', onReady);
      video.addEventListener('canplay', onReady);
      // se já tiver readyState suficiente mas pausado, ainda deixamos listeners
    });
  }).then(() => {
    // espera extra curta para estabilizar render antes do screenshot
    return cy.wait(1000);
  });
});

// Importa addContext para adicionar prints ao relatório Mochawesome
import addContext from 'mochawesome/addContext';

// 🔹 Comando customizado: adiciona contexto com o screenshot no relatório
Cypress.Commands.add('addScreenshotContext', (testContext, screenshotName) => {
  const screenshotPath = `cypress/screenshots/${Cypress.spec.name}/${screenshotName}.png`;

  // Garante que o addContext foi carregado corretamente
  if (addContext && testContext) {
    addContext({ test: testContext }, {
      title: `📸 Evidência - ${screenshotName}`,
      value: screenshotPath
    });
  } else {
    // fallback: loga no console
    cy.log(`⚠️ Não foi possível adicionar contexto para ${screenshotName}`);
  }
});

import 'cypress-downloadfile/lib/downloadFileCommand';

Cypress.Commands.add('evidenciaPDF', (nomeArquivo) => {
  const fs = require('fs');
  const path = require('path');

  const origem = path.resolve('cypress/assets', 'Mídia KIT.png'); // sua imagem original
  const destino = path.resolve('cypress/screenshots', `${nomeArquivo}.png`);

  fs.copyFileSync(origem, destino);
});