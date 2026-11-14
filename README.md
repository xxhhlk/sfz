# sfz - 图片水印打码工具

专门用于给身份证等敏感证件打码的工具，完全基于浏览器本地API，无任何网络请求

## 构建

```bash
npm install
npm run build
```

`public/` 下的 `script.js`、`heic-worker.js` 和 `vendor/` 都是构建产物，不入库。

## 第三方组件

`public/vendor/` 下的 `libheif.js`、`libheif.wasm` 来自 [libheif-js](https://github.com/catdad-experiments/libheif-js)（LGPL-3.0），用于在浏览器不支持 HEIC 时本地解码，随构建从 `node_modules` 复制，页面不会向任何第三方发起请求。
