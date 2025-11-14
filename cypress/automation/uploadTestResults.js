// automation/uploadTestResults.js
const path = require('path');
const fs = require('fs');
const AzureApi = require('./azureApi');
const { loadMochawesomeJson, extractTestsFromMochawesome, findScreenshotsForTest } = require('./helpers');

async function main() {
  try {
    const org = process.env.AZ_ORG;
    const project = process.env.AZ_PROJECT;
    const token = process.env.AZ_TOKEN || process.env.AZURE_PAT;

    if (!org || !project || !token) {
      throw new Error('Variáveis de ambiente AZ_ORG, AZ_PROJECT e AZ_TOKEN (ou AZURE_PAT) são obrigatórias.');
    }

    const azure = new AzureApi({ organization: org, project, token });

    console.log('📂 Carregando mapeamento...');
    const mapping = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'test-mapping.json'), 'utf8'));

    console.log('📂 Carregando relatório mochawesome...');
    const mochPath = path.resolve('cypress/reports/html/mochawesome.json');
    const moch = loadMochawesomeJson(mochPath);
    const tests = extractTestsFromMochawesome(moch);
    console.log(`🔎 ${tests.length} testes extraídos do relatório.`);

    // Cria Test Run
    console.log('🚀 Criando Test Run no Azure DevOps...');
    const run = await azure.createTestRun(`Cypress Run - ${new Date().toISOString()}`);
    const runId = run.id;
    console.log(`✅ Test Run criado: id=${runId}`);

    // Para resultados em lote
    const resultsPayload = [];

    // For each mapping entry, locate test in mochawesome
    for (const [testName, { testCaseId, step }] of Object.entries(mapping)) {
      // tentamos procurar test por título que contenha testName (case-insensitive)
      const testObj = tests.find(t => {
        const candidates = [t.fullTitle, t.title, (t.titlePath || []).join(' ')];
        return candidates.some(c => c && c.toLowerCase().includes(testName.toLowerCase()));
      });

      if (!testObj) {
        console.warn(`⚠️ Test não encontrado no mochawesome: "${testName}". Será criado um resultado SKIPPED.`);
        resultsPayload.push({
          testCase: { id: testCaseId },
          outcome: 'NotExecuted',
          comment: `Teste mapeado mas não encontrado no mochawesome: "${testName}".`
        });
        continue;
      }

      const outcome = (testObj.pass === true) ? 'Passed' : (testObj.fail === true ? 'Failed' : (testObj.pending ? 'NotExecuted' : 'Failed'));
      const titleForResult = testObj.fullTitle || testObj.title;

      resultsPayload.push({
        testCase: { id: testCaseId },
        outcome,
        state: 'Completed',
        comment: `Automated result from Cypress. Mapped test: "${testName}". Source test title: "${titleForResult}". Step: ${step}`
      });
    }

    // POST all results to create them and get resultIds
    console.log('📨 Criando resultados no Test Run...');
    const createResultsResp = await azure.createTestResults(runId, resultsPayload);
    const createdResults = createResultsResp.value || [];
    console.log(`✅ ${createdResults.length} resultados criados.`);

    // Now attach screenshots for each createdResult based on mapping
    for (const created of createdResults) {
      const tcId = created.testCase && created.testCase.id;
      // find mapping entry for this testCaseId (there might be multiple mapped tests to same TC; we'll match by comment)
      const comment = created.comment || '';
      // extract original mapped test name from comment (we added it)
      const matched = comment.match(/Mapped test: "(.*)".*Step: (\d+)/);
      let mappedTestName = null;
      let stepNumber = null;
      if (matched) {
        mappedTestName = matched[1];
        stepNumber = matched[2];
      }

      // find testObj again
      const testObj = tests.find(t => {
        const candidates = [t.fullTitle, t.title, (t.titlePath || []).join(' ')];
        return candidates.some(c => c && mappedTestName && c.toLowerCase().includes(mappedTestName.toLowerCase()));
      });

      if (!testObj) {
        console.warn(`⚠️ Não foi possível localizar objeto de teste para anexos (testCase ${tcId}). Pulando attachments.`);
        continue;
      }

      // find screenshots
      const screenshotPaths = findScreenshotsForTest(testObj);
      if (!screenshotPaths.length) {
        console.warn(`⚠️ Nenhum screenshot encontrado para teste "${mappedTestName}"`);
        continue;
      }

      for (const p of screenshotPaths) {
        const content = fs.readFileSync(p);
        const b64 = content.toString('base64');
        const filename = `${path.basename(p)}`; // keep original name
        const commentForAttachment = `Attachment for mapped test "${mappedTestName}" - step ${stepNumber}. Source file: ${p}`;
        console.log(`📎 Enviando attachment ${filename} para testCase ${tcId} (resultId ${created.id})`);
        await azure.uploadAttachment(runId, created.id, filename, b64, commentForAttachment);
        console.log(`   ✅ Anexo enviado: ${filename}`);
      }
    }

    console.log('🎉 Processo finalizado. Test Run com evidências criado no Azure DevOps.');
    console.log(`RunId: ${runId}`);
    console.log('Obs: os anexos ficam associados aos Test Results (no Test Run). O nome/descrição do anexo contém o número do Step para referência.');
  } catch (err) {
    console.error('❌ Erro no uploadTestResults:', err.message || err);
    console.error(err.stack || '');
    process.exit(1);
  }
}

main();