Cypress.Commands.add('waitForVideo', (selector) => {
  cy.get(selector, { timeout: 90000 })
    .should('be.visible')
    .and(($video) => {
      const src = $video.attr('src')
      expect(src).to.be.a('string').and.include('blob:')
    })

  cy.get(selector).then(($video) => {
    const el = $video[0]
    return new Cypress.Promise((resolve) => {
      const check = setInterval(() => {
        if (!el.paused && el.readyState >= 2) {
          clearInterval(check)
          resolve()
        }
      }, 500)
    })
  })
})