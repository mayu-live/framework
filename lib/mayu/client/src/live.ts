import Mayu from './Mayu.js'

const url = new URL(import.meta.url)
const id = url.search.slice(1)

if (!id) {
  throw new Error('Missing id query parameter')
}

window.Mayu = new Mayu(id)
