/// <reference types="cypress" />
import 'cypress-mochawesome-reporter/register';

describe('Teste 2: Editar Dados da Câmera - Endereço RTSP válido', () => {

  beforeEach(() => {
    cy.visit('/login');
    cy.contains('button', 'Entrar com login e senha').click();
    cy.get('#login-usuario', { timeout: 10000 }).type('38733955840', { log: false });
    cy.get('#login-senha').type('38733955840', { log: false });
    cy.contains('button', 'Entrar').click();
    cy.contains('Bem-vindo ao Portal do Colaborador!', { timeout: 30000 }).should('be.visible');
    cy.contains('Bem-vindo ao Portal do Colaborador!', { timeout: 30000 }).should('not.exist');
    cy.contains('strong', 'COLABORADOR MURALHA PAULISTA').click();
  });

  it('Deve validar todos os dados e validar RTSP com sucesso', () => {
    cy.fixture('cameras').then((dados) => {
      cy.contains('td.cdk-column-descricaoCamera', dados.nomeCamera).parents('tr').find('[tooltip="Editar"]').click();

      cy.get('input[formcontrolname="descricaoCamera"]').should('exist');
      cy.log('✅ Tela de edição carregada com sucesso.');

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

      Object.entries(camposTexto).forEach(([campo, esperado]) => {
        const seletor = campo === 'enderecoRTSP'
          ? `#${campo}`
          : `input[formcontrolname="${campo}"]`;

        cy.get(seletor, { timeout: 30000 }).should('have.value', esperado);
      });

      const camposSelect = {
        tipoLocal: dados.tipoLocal,
        tipoStream: dados.tipoEndereco
      };

      Object.entries(camposSelect).forEach(([campo, esperado]) => {
        cy.get(`ng-select[formcontrolname="${campo}"] .ng-value-label`, { timeout: 60000 })
          .should('be.visible')
          .should(($el) => {
            const texto = $el.text().trim();
            // Evita comparar enquanto ainda é um UUID
            if (/^[0-9a-f-]{36}$/i.test(texto)) {
              throw new Error('aguardando label final do ng-select');
            }
            expect(texto, `❌ Select "${campo}" incorreto. Esperado: ${esperado}`).to.include(esperado);
          });
      });

      cy.contains('button', 'Limpar RTSP').click();
      cy.get('#enderecoRTSP').type('rtsp://agatha:Agatha@servidoregide.ddns.net:8556/Interface/Cameras/Media?Camera=Lado Esquerdo B&Profile=Recording2525', { log: false });
      cy.contains('button', 'Validar RTSP').click();

      cy.get('i.fa-circle-check', { timeout: 20000 }).should('have.class', 'text-success');
      cy.screenshot('RTSP validado com sucesso');

      cy.contains('button', 'Visualizar vídeo ', { timeout: 60000 }).click();
      cy.waitForVideo('.modal-content video.vjs-tech');
      cy.screenshot('Vídeo carregado com sucesso');

      cy.get('.modal-content button.btn.btn-primary[type="button"]').filter(':visible').click();
      cy.contains('button', 'Avançar').click();
      cy.contains('Salvo com sucesso!', { timeout: 30000 }).should('be.visible');
      cy.screenshot('Salvo com sucesso exibido');
      cy.contains('Salvo com sucesso!', { timeout: 30000 }).should('not.exist');
      cy.contains('button', 'Sair').click();
    });
  });
});
