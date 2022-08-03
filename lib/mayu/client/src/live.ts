import Mayu from './Mayu.js'

const url = new URL(import.meta.url)
const id = url.search.slice(1)

document.querySelector(`script[src*="${url.pathname}"]`)?.remove()

if (!id) {
  throw new Error('Missing id query parameter')
}

window.Mayu = new Mayu(id)
