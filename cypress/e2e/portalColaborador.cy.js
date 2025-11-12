/// <reference types="cypress" />
import 'cypress-mochawesome-reporter/register';

Cypress.Screenshot.defaults({
  screenshotOnRunFailure: false
});

describe('Consulta Dados da Câmera', () => {

  beforeEach(() => {
    cy.visit('/login');
    cy.contains('button', 'Entrar com login e senha').click();
    cy.get('#login-usuario', { timeout: 10000 }).type('38733955840', { log: false });
    cy.get('#login-senha').type('38733955840', { log: false });
    cy.contains('button', 'Entrar').click();
    cy.contains('Bem-vindo ao Portal do Colaborador!', { timeout: 10000 }).should('be.visible');
    cy.contains('Bem-vindo ao Portal do Colaborador!', { timeout: 10000 }).should('not.exist');
    cy.contains('strong', 'COLABORADOR MURALHA PAULISTA').click();
  });

  it('Deve validar todos os dados da câmera cadastrada', () => {
    cy.fixture('cameras').then((dados) => {

      // Acessa câmera
      cy.contains('td.cdk-column-descricaoCamera', dados.nomeCamera, { timeout: 10000 })
        .parents('tr')
        .find('[tooltip="Consultar"]')
        .click();

      cy.get('input[formcontrolname="descricaoCamera"]', { timeout: 20000 }).should('exist');

      // Valida campos de texto
      const camposTexto = {
        descricaoCamera: dados.nomeCamera,
        enderecoRTSP: dados.enderecoRTSP,
        latitude: dados.latitude,
        longitude: dados.longitude,
        logradouro: dados.logradouro,
        numero: dados.numero,
        descricaoBairro: dados.bairro,
        cidade: dados.cidade,
        estado: dados.estado,
        cep: dados.cep
      };

      Object.entries(camposTexto).forEach(([campo, valor]) => {
        const seletor = campo === 'enderecoRTSP'
          ? `#${campo}`
          : `input[formcontrolname="${campo}"]`;
        cy.get(seletor, { timeout: 10000 }).should('have.value', valor);
      });

      // Valida selects
      const camposSelect = {
        tipoLocal: dados.tipoLocal,
        tipoStream: dados.tipoEndereco
      };

      Object.entries(camposSelect).forEach(([campo, valor]) => {
        cy.get(`ng-select[formcontrolname="${campo}"] .ng-value-label`, { timeout: 10000 })
          .should('contain.text', valor);
      });

      cy.wait(1000);

      // Screenshot 01
      cy.screenshot('01_validou_selects');

      // Valida vídeo
      cy.contains('button', 'Visualizar vídeo ', { timeout: 60000 }).click();
      cy.waitForVideo('.modal-content video.vjs-tech');

      // Screenshot 02
      cy.screenshot('02_video_carregado');

      // Fecha modal e encerra sessão
      cy.get('.modal-content button.btn.btn-primary[type="button"]', { timeout: 10000 })
        .filter(':visible')
        .click();
      cy.contains('button', 'Voltar').click();
      cy.contains('button', 'Sair').click();
    });
  });
});
