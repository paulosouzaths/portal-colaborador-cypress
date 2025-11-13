/// <reference types="cypress" />
import 'cypress-mochawesome-reporter/register';

describe('Teste 5: Consulta Tela do Midia Kit', () => {
  const urlPDF = 'https://www1.portaldaseguranca.sp.gov.br:3200/assets/pdf/Placa%20Colaborador%20Muralha%20Paulista.pdf';

  beforeEach(() => {
    cy.visit('/login');

    // Login
    cy.contains('button', 'Entrar com login e senha').click();
    cy.get('#login-usuario', { timeout: 10000 }).type('38733955840', { log: false });
    cy.get('#login-senha').type('38733955840', { log: false });
    cy.contains('button', 'Entrar').click();

    // Espera a tela inicial carregar
    cy.contains('Bem-vindo ao Portal do Colaborador!', { timeout: 30000 }).should('be.visible');
    cy.contains('Bem-vindo ao Portal do Colaborador!', { timeout: 30000 }).should('not.exist');

    // Acessa o card "MÍDIA KIT"
    cy.contains('strong', 'MÍDIA KIT').click();
  });

  it('Deve conter arquivo PDF esperado', () => {
    // Faz a requisição direta ao PDF para validar conteúdo
    cy.request({
      url: urlPDF,
      encoding: 'binary', // permite leitura binária
    }).then((response) => {
      expect(response.status).to.eq(200);
      expect(response.headers['content-type']).to.include('pdf');

      // Converte o corpo binário para texto simples para checar o conteúdo
      const pdfText = Buffer.from(response.body, 'binary').toString('latin1');

      // Valida se o texto esperado existe
      expect(pdfText).to.include('Muralha Paulista');

      // Evidência visual
      cy.screenshot('Midia Kit - PDF validado com sucesso');
    });
  });

  // Captura print adicional em caso de falha
  afterEach(function () {
    if (this.currentTest.state === 'failed') {
      cy.screenshot(`MidiaKit_FALHA_${this.currentTest.title}`, { capture: 'runner' });
    }
  });
});
