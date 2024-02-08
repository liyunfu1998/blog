---
title: 手动搭建一个SSR mvp项目
description: 手动搭建一个SSR mvp项目
pubDatetime: 2024-01-15T15:11:00Z
slug: ssr-mvp
---

## 手动搭一个SSR项目

### 服务器端渲染的优点

- 提高渲染速度：它在服务器上进行预渲染并减少加载时间
- 更好的搜索引擎优化：搜索引擎变得更好，因为它们可以轻松地对SSR应用程序中的内容进行排名和索引
- 增强的用户体验：用户可以更快地获得内容并增强性能
- 可及性：即使禁止了javascript，用户也可以使用内容
- 在社交媒体上分享：在社交媒体平台上共享URL时，它会生成准确的预览

### 一个完整的SSR项目需要实现什么

- 设置服务器：选择服务器端框架(如Express.js)来处理SSR请求
- React水合作用：在服务器上呈现HTML后，javascript会使其具有交互性
- 获取数据：异步数据提取或在渲染前获取内容等技术`getInitialProps`
- 处理路由：配置服务器路由以处理不同的URL和路由

### 优化SSR应用中的性能

- 缓存：缓存可以缩短渲染时间，因为缓存会渲染页面并缩短加载时间
- ISR：ISR是增量静态再生，它使用动态数据生成和缓存页面
- 客户端导航：初始加载后，客户端导航可改善用户体验

### 实现基于React的SSR

#### 步骤一：写一个最简SSR

目前我们的服务端框架选择的是`Express.js`，打包工具选择的是`Webpack`，现在就先将依赖安装完成吧

```shell
pnpm i express
pnpm i @babel/preset-env babel-loader nodemon ts-loader webpack webpack-cli webpack-merge -D
```

先在根目录下新建`src/server/index.js`

```shell
mkdir -p src/server
touch src/server/index.js
```

编辑`index.js`

```js
import express from "express";
import childProcess from "child_process";

const app = express();

app.get("*", (req, res) => {
  res.send(`
    <html>
      <body>
        <div>hello ssr</div>
      </body>
    </html>
  `);
});

app.listen(3000, () => {
  console.log("Server is listening on port 3000");
});

childProcess.exec("start http://localhost:3000/");
```

现在来配置`webpack.base.js`，主要是配置针对js、ts的通用loader方案

```js
const path = require("path");

module.exports = {
  module: {
    rules: [
      {
        test: /\.js$/,
        loader: "babel-loader",
        exclude: /node_modules/,
        options: {
          presets: ["@babel/preset-env"],
        },
      },
      {
        test: /.(ts|tsx)$/,
        use: "ts-loader",
        exclude: /node_modules/,
      },
    ],
  },
  resolve: {
    extensions: [".tsx", ".ts", ".js"],
    alias: {
      "@": path.resolve(process.cwd(), "src"),
    },
  },
};
```

继续配置`webpack.server.js`，配置入口文件，及打包结果

```js
const { merge } = require("webpack-merge");
const baseConfig = require("./webpack.base");

module.exports = merge(baseConfig, {
  mode: "development",
  entry: "./src/server/index.js",
  target: "node",
  output: {
    filename: "bundle.js",
    path: path.resolve(__dirname, "server_build"),
  },
});
```

设置`package.json`的脚本命令

```json
  "scripts": {
    "start": "npx nodemon server_build/bundle.js",
    "build:server": "npx webpack build --config ./webpack.server.js --watch"
  },
```

运行`npm run build:server`后可以看到成功打包后的文件`server_build/bundle.js`

现在我们运行`npm run start` 打开浏览器页面刷新可以在`Network`中看到请求的数据
![ssr初版](https://assets.liyunfu.tech/images/202402081126036.png)

目前我们看到的就是SSR初版，即拿回来的页面直接就是带有数据的，而不是客户端渲染那种只有一个`div id='root'`类型，当然现在这个版本是完全不能用的，先`pr`一波，顺便Tips：项目中还配置了`tsconfig.json`需要的前往仓库获取
[SSR初版实现](https://github.com/liyunfu1998/react-ssr-template/commit/37630e96ec62c362fea4a35ac27e261b4edae416)

#### 步骤二：渲染静态DOM

目前我们实现的只是一个模板字符串渲染，完全不可用，现在需要实现React组件渲染为字符串输出，下面来实现它吧

我们需要先安装`React ReactDOM`的依赖

```shell
pnpm i react react-dom
pnpm i @types/react @types/react-dom @types/node @babel/preset-react  -D
```

现在我们来写一个React的Home组件

```shell
mkdir -p src/pages/Home
touche src/pages/Home/index.tsx
```

```js
import { FC } from "react";

const Home:FC=()=>{
  return (
    <div>
      <h1>hello-ssr</h1>
      <button onClick={():void=>{alert('hello-ssr')}}>alter</button>
    </div>
  )
}

export default Home
```

修改`tsconfig.json`配置，`noEmit`为`false`

```json
{
  "compilerOptions": {
    "module": "CommonJS",
    "types": ["node"], // 声明类型，使得ts-node支持对tsx的编译
    "jsx": "react-jsx", // 全局导入, 不再需要每个文件定义react
    "target": "es6",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": false,
    "baseUrl": "./",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*"]
}
```

修改`webpack.base.js`，对于js做loader的时候，还需要添加`react`预设，`presets: ["@babel/preset-env", "@babel/preset-react"],`

然后我们在`src/server/index.js`中引入`Home`组件，转换成HTMl

```js
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import React from "react";
import Home from "@/pages/Home";

const app = express();
const content = renderToString(<Home />); // 编译需要渲染的jsx，转换成对应的html

app.get("*", (req, res) => {
  const htmlDOM = `
    <html>
      <body>
        <div id="root">${content}</div>
      </body>
    </html>
  `;
  res.send(htmlDOM);
});

app.listen(3000, () => {
  console.log("Server is listening on port 3000");
});

childProcess.exec("start http://localhost:3000/");
```

现在打包并运行效果如下：
![SSR渲染静态DOM](https://assets.liyunfu.tech/images/202402081245420.png)

代码如下：[SSR渲染静态DOM](https://github.com/liyunfu1998/react-ssr-template/commit/af68ed4def79534823eb6dac97631e3a6f9553a9)
为什么我们点击`alert`按钮没效果呢，这就涉及到`同构`了，即同一套React代码在服务器端渲染一遍，然后在客户端再执行一遍，服务端负责静态dom的拼接，而客户端负责事件的绑定，不仅是模板页面渲染，后面的路由，数据的请求都涉及到同构，

#### 步骤三：实现客户端部分

新增一个`src/client/index.tsx`，前面我们的`src/server/index.js`也可以改变为tsx结尾

```js
// src/client/index.tsx

import { hydrateRoot } from "react-dom/client";
import Home from "@/pages/Home";

hydrateRoot(document.getElementById("root") as Document | Element, <Home />);
```

`hydrateRoot`需要指定一个绑定的真实`dom`，我们这里给他设置为`root`

再进行客户端的`webpack.client.js`配置

```js
const path = require("path");
const { merge } = require("webpack-merge");
const baseConfig = require("./webpack.base");

module.exports = merge(baseConfig, {
  mode: "development",
  entry: "./src/client/index.tsx",
  output: {
    filename: "index.js",
    path: path.resolve(process.cwd(), "client_build"),
  },
});
```

主要逻辑就是打包，输出到`client_build`目录下

然后我们在`src/server/index.tsx`中引入

首先将`client_build`目录设置为静态资源目录

```js
app.use(express.static(path.resolve(process.cwd(), "client_build")));
```

然后在模板字符串里面引入脚本

```js
<script src="/index.js"></script>
```

完整`src/server/index.js`代码如下：

```js
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import React from "react";
import Home from "@/pages/Home";
import path from "path";

const app = express();
const content = renderToString(<Home />); // 编译需要渲染的jsx，转换成对应的html

app.use(express.static(path.resolve(process.cwd(), "client_build")));

app.get("*", (req, res) => {
  const htmlDOM = `
    <html>
      <body>
        <div id="root">${content}</div>
        <script src="/index.js"></script>
      </body>
    </html>
  `;
  res.send(htmlDOM);
});

app.listen(3000, () => {
  console.log("Server is listening on port 3000");
});

childProcess.exec("start http://localhost:3000/");
```

最后添加一个新的启动脚本命令

```json
"build:client": "npx webpack build --config ./webpack.client.js --watch",
```

运行情况如下：
![SSR事件绑定](https://assets.liyunfu.tech/images/202402081316053.png)

可以看到截图中，先请求的html页面，并且紧接着获取了`index.js`脚本，点击`alert`有效果了

代码如下：[SSR事件绑定](https://github.com/liyunfu1998/react-ssr-template/commit/f5349bce32102ca9b969acc1ccba5094487a9765)

## 针对大图低网速加载场景的首屏优化方案

### 方案一

针对该场景，我们首先需要知道的是什么时候是`低网速`的，目前浏览器提供了`navigator.connection.effectiveType`来获取当前的流量状态，这样我们就可以根据不同的网速场景，进行图片清晰度的选择，`API`返回的结果如下：

1. `slow-2g`
2. `2g`
3. `3g`
4. `4g`

在低网速下优先加载0.5X或1X的图片，同时也加载2X的大图，通过隐藏DOM的方式隐性加载，然后监听2X资源的`onload`事件，在资源加载完成时，进行类的替换

但是当前为实验性属性，兼容性不太好，如果用户非`safari` 、`firefox`用户，那可以尽情使用

### 方案二

针对不同的像素场景也需要使用响应式图片，即pc可能更清晰，h5可以低画质一些，浏览器给我们提供了`img srcset`和`picture`，可以根据不同的像素场景自动选取不同的元素进行适配

```js
//img srcset
<img srcset="abc-480w.jpg 480, abc-800w.jpg 800w" sizes="{max-width: 600px} 480px, 800px" src="abc-800w.jpg">

// picture
<picture>
    <source srcset="/media/abc-240-200.jpg" media="(min-width: 800px)">
    <img src="/media/abc-298-332.jpg" />
</picture>
```

### 方案三

使用webp格式图片，基本上可以比原有jpg降低40%体积，因为一些浏览器不支持webp，需要进行兼容性判断：

```js
export const getIsSupportWebp = (context: AppContext) => {
    const {headers = {} } = context.ctx.req || {}
    return headers.accept?.include('image/webp')
}
```

### 为什么在极快速度下webp反倒相对更慢

因为webp的低体积并不是毫无代价的，他在压缩过程中进行了`分块`、`帧内预测`、`量化`等操作，这些操作减少了webp的体积，但是作为交换的事，`需要更长的解析时间`，不过这不是受网速限制，是受浏览器限制，但是几毫秒差距的用户体验并不会多大影响，反倒是随着网速变差，体积优化的效果很显著

## IOS设备兼容

### 300 ms delay

在平时的开发事件的触发大部分都是立刻响应的，但是IOS设备，会有300ms的延迟，因为IOS浏览器双击屏幕可以进行缩放，当用户点击链接后，浏览器没办法判定用户是想双击缩放，还是进行点击事件触发，所以IOS Safari会统一等待300ms，来判断用户是否会再次点击屏幕

#### 解决方案

> 1. Meta禁止缩放
> 2. 更改视口尺寸
> 3. Touch-action

**Meta禁止缩放**
因为300ms延迟的初衷是为了解决点击和缩放没办法区分的问题，针对不需要缩放的页面，我们可以通过禁止缩放来解决，大部分页面都是可以避免缩放，通过某些交互样式来兼容缩放的

```js
// 在head中加着两行即可
<meta name="viewport" content="user-scalable=no" >
<meta name="viewport" content="initial-scale=1,maximum-scale=1">
```

**更改视口尺寸**
chrome对于`width=device-width`或者比`viewport`更小的页面禁用双击，但是IOS的Safari不支持，这个属性可以让浏览器自适应设备的屏幕尺寸

```js
<meta name="viewport" content="width=device-width">
```

**Touch-action**

> 这是草案

使用css属性，`touch-action: none`可以移除目标元素的300ms delay

### 橡皮筋问题

> IOS上，当页面滚动到顶部或底部仍可向下或向上拖拽，并伴随一个弹性的效果，该效果被称为'rubber band'

#### 解决方案

我们给body甚至`overflow:hidden`，然后对根结点设置100页宽的高度，**将外部body的滚动移动到页面内，这样外界的滚动相关的问题都会解决**，因为我们页面采用的实际是内部滚动

```js
.forbidScroll {
	height: 100vh;
	overflow: hidden
}
body {
	overflow: hidden
}
#__next: {
  height: 100vh;
  overflow: auto
}
```

## 如何做SEO优化

### 技术优化

#### 语义化标签

> 1. H1是一个页面中权重最高，关键词优先级最高的文案，一个页面只能使用一个
> 2. 页面中我们通常只使用H1~H3，剩下的标题优先级太低，部分搜索引擎不会进行识别
> 3. H标签通常不适用在文字logo、标题栏、侧边栏等每页固定存在的部分，因为这部分不属于这一页的重点，既不是与众不同的区域

#### Meta

> 1. Title
> 2. Description：页面描述，SEO的关键；PC端不要超过155个字符，移动端不要超过120个字符，如果过长，页面描述会被截断，反而影响最终的SEO
> 3. Keywords：关键词，每个页面通常设置比较重要的3、4个关键字；关键词由高到低用逗号分隔，每个关键词都要是独特的，不要每个关键词意思差不多
> 4. robots：是否开启搜索引擎抓去，noindex对应是否开启抓去，nofollow对应不追踪网页的链接，需要开启
> 5. Applicable-device：告诉Google，你这个站点适配了那些设备，不加就是默认PC端，将会影响移动端搜索你站点
> 6. Format-detection：在默认状态下，网页的数字会被认为是电话号码，点击数字会被当作电话号码，所以需要禁用

```
<meta name="format-detection" content="telephone=no" />
```

#### Sitemap

[欢迎使用 Google Search Console](https://search.google.com/search-console/not-verified?original_url=/search-console/users&original_resource_id)
在谷歌添加
