// automation/azureApi.js
const axios = require('axios');

class AzureApi {
  constructor({ organization, project, token }) {
    this.organization = organization;
    this.project = project;
    this.baseUrl = `https://dev.azure.com/${organization}/${project}/_apis`;
    this.auth = {
      headers: {
        Authorization: `Basic ${Buffer.from(':' + token).toString('base64')}`,
        'Content-Type': 'application/json'
      }
    };
  }

  async createTestRun(name = 'Cypress Automated Run') {
    const url = `${this.baseUrl}/test/runs?api-version=7.0`;
    const body = { name, automated: true };
    const res = await axios.post(url, body, this.auth);
    return res.data; // includes id
  }

  // create results in bulk (array of results)
  async createTestResults(runId, results) {
    const url = `${this.baseUrl}/test/Runs/${runId}/results?api-version=7.0`;
    const res = await axios.post(url, results, this.auth);
    return res.data;
  }

  // upload attachment to a result
  async uploadAttachment(runId, resultId, attachmentName, base64Content, comment) {
    const url = `${this.baseUrl}/test/Runs/${runId}/results/${resultId}/attachments?api-version=7.0`;
    const body = {
      stream: base64Content,
      fileName: attachmentName,
      attachmentType: 'GeneralAttachment',
      comment: comment || ''
    };
    const res = await axios.post(url, body, this.auth);
    return res.data;
  }
}

module.exports = AzureApi;