import js from '@eslint/js';
import vue from 'eslint-plugin-vue';

export default [
  { ignores: ['dist', 'node_modules'] },
  js.configs.recommended,
  ...vue.configs['flat/recommended'],
  {
    rules: {
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      'vue/multi-word-component-names': 'off'
    }
  }
];
