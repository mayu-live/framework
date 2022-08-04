import type Mayu from './Mayu.js'

declare global {
  interface Node {
    __MAYU_ID: number
  }

  interface Window {
    Mayu: Mayu
  }

  interface Document {
    adoptedStyleSheets: any[];
  }
}
