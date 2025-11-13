// scripts/merge-reports.js
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const reportsDir = path.join(process.cwd(), 'cypress', 'reports', 'html');
const outFile = path.join(reportsDir, 'mochawesome.json');

try {
  if (!fs.existsSync(reportsDir)) {
    console.error(`Diretório não encontrado: ${reportsDir}`);
    process.exit(1);
  }

  const allJsons = fs.readdirSync(reportsDir)
    .filter(f => f.toLowerCase().endsWith('.json'))
    // ignora mochawesome.json principal (possível arquivo vazio)
    .filter(f => f !== 'mochawesome.json')
    // junta caminho absoluto + filtra arquivos não vazios
    .map(f => path.join(reportsDir, f))
    .filter(p => {
      try {
        return fs.statSync(p).size > 0;
      } catch (e) {
        return false;
      }
    });

  if (!allJsons.length) {
    console.error('ERROR: nenhum relatório JSON válido encontrado em', reportsDir);
    console.error('Arquivos que existem:', fs.readdirSync(reportsDir));
    process.exit(1);
  }

  // executa mochawesome-merge com a lista de arquivos e captura stdout
  console.log('Arquivos para merge:', allJsons.map(p => path.basename(p)).join(', '));
  const stdout = execFileSync('npx', ['mochawesome-merge', ...allJsons], { encoding: 'utf8' });

  // grava o JSON final
  fs.writeFileSync(outFile, stdout, 'utf8');
  console.log('Merge concluído ->', outFile);
  process.exit(0);
} catch (err) {
  console.error('Erro ao mesclar reports:', err && err.message ? err.message : err);
  process.exit(1);
}
