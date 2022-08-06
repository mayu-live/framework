import typescript from '@rollup/plugin-typescript';
import { terser } from "rollup-plugin-terser";

export default {
  input: 'src/live.ts',
  output: {
    dir: 'dist/',
    format: 'esm'
  },
  plugins: [typescript(), terser()]
};
