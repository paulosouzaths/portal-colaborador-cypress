/// <reference types="cypress" />
import 'cypress-mochawesome-reporter/register';

describe('Teste 4: Consulta Tela do FAQ', () => {
  beforeEach(() => {
    cy.visit('/login');
    cy.contains('button', 'Entrar com login e senha').click();
    cy.get('#login-usuario', { timeout: 10000 }).type('38733955840', { log: false });
    cy.get('#login-senha').type('38733955840', { log: false });
    cy.contains('button', 'Entrar').click();
    cy.contains('Bem-vindo ao Portal do Colaborador!', { timeout: 30000 }).should('be.visible');
    cy.contains('Bem-vindo ao Portal do Colaborador!', { timeout: 30000 }).should('not.exist');
    cy.contains('strong', 'FAQ PERGUNTAS FREQUENTES').click();
  });

  it('Deve exibir todo o texto corretamente', () => {
    const trechos = [
      'Perguntas Frequentes',
      'Quantas câmeras eu posso cadastrar no Portal do Colaborador?',
      'Inicialmente não há limite de câmeras para cadastro',
      'Quais câmeras posso cadastrar no Portal do Colaborador?',
      'Como eu posso cadastrar câmeras no Portal do Colaborador?',
      'O que é DDNS e como habilitar?',
      'Como configurar DDNS:',
      'O que é IP público fixo?',
      'Além de habilitar o DDNS preciso de IP público fixo?',
      'Como encontrar o RTSP da minha câmera?',
      'Como configurar RTSP:',
      'O que é a liberação de portas no roteador e como habilitar?',
      'Eu consigo visualizar a imagem da minha câmera em tempo real?',
      'Se eu não quiser mais disponibilizar as imagens da minha câmera, como faço isso?'
    ];

    // Verifica cada trecho na página inteira
    trechos.forEach((texto) => {
      cy.contains(texto, { timeout: 20000 }).should('be.visible');
    });

    cy.wait(1000);
    cy.screenshot('FAQ - Texto validado com sucesso');
    cy.contains('button', 'Sair').click();
  });
});
