---
title: 如何实现 SSR 的静态页面渲染？
description: 如何实现 SSR 的静态页面渲染？
pubDatetime: 2024-01-15T15:11:00Z
modDatetime: 2023-01-15T15:15:00Z
author: 李云富
slug: ssr-art
featured: true
draft: false
tags: ["React Native", "React"]
ogImage: "https://astro-paper.pages.dev/_astro/AstroPaper-v4.E8pWr1CH_Zmry1N.webp.webp"
canonicalURL: "https://blog.liyunfu.tech/posts/react-native-support-web"
---

> 仓库地址：https://github.com/czm1290433700/ssr-server

上一节，我们搭建了代码的 lint，写了一个很简单的服务器端 demo，并通过运行构建产物的方式运行了项目，对于上次的页面，大家打开 network 可以看到它向服务器端的请求是一个完整的 HTML。

![image.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/263f09614cbf41ef9299c47f188f6f22~tplv-k3u1fbpfcp-watermark.image?)

在前几节，我们介绍过服务器端渲染的特点就是所有 dom 、数据的拼接在服务器端完成，使得在客户端拿到的是一个完整的 url，这个其实就是服务器端渲染，但是这里我们是通过 send 直接返回的 HTML 字符串，和我们渲染静态页面的预期还有差距，那么我们应该怎么在现在的基础上去渲染一个静态页面呢？

一个应用渲染静态页面的过程，其实可以分为以下三个步骤：

- 模板页面的渲染：即 HTML中 body 标签下的 dom 内容，像我们平时写一个基于 React 或是 Vue 的前后端分离项目，首先我们会去编写对应页面的模板模块，再写相关的数据请求，最后统一导出进行页面的渲染。

<!---->

- 路由的匹配：一个 Web 工程下可能会有多个模板页面需要渲染，我们会使用路由去对应指定的模板页面进行渲染，体现在浏览器中，也就是我们域名后的后缀。

<!---->

- header标签的修改：模板页面本身是没办法去修改页面的 header 标签的，但是修改 header 标签的需求其实并不少见，类似修改站点的标题， 或是进行多媒体适配，可能都需要对 header 标签有一定修改。

包括上面三个能力的静态渲染才是完整的，这点对于 SSR 也是类似的，所以这小节我们将就三个方面来完成 SSR 的静态页面渲染。

# 模板页面的渲染

我们先安装一下 React 模板相关的依赖， 然后在 src/pages 下创建一个简单的模板页面。这边是使用 React 函数式的写法来搭建模板而不是创建类的形式，在大型项目中， React 函数式的写法不需要创建实例，可以按照实际的业务情形来拆分组件的粒度，加上有 react hook 的帮助，我们已经不再需要去过多关注生命周期，相反更多是一种“组合大于继承”的思想，对大家理解函数式编程也会有大的帮助。

```
npm install react react-dom --save
npm install @types/react @types/react-dom --save-dev
```

```
// ./src/pages/Home/index.tsx
const Home = () => {
  return (
    <div>
      <h1>hello-ssr</h1>
      <button
        onClick={(): void => {
          alert("hello-ssr");
        }}
      >
        alert
      </button>
    </div>
  );
};

export default Home;
```

模板创建好了，现在我们需要思考，怎么才能把这个模板转换成 HTML 标签传递给服务器端呢？这里我们可以使用 react-dom 中暴露的 renderToString 方法，这个方法可以把模板元素转换成 HTML 字符串返回。它的底层和客户端模板编译其实是一样的，都是根据 AST （也就是虚拟 DOM ）来转化成真实 DOM 的过程，React 在它的基础上，提供了更多流相关的能力，返回了一套 server 相关的 api，感兴趣的同学可以阅读[ React 官方文档对应的描述](https://reactjs.org/docs/react-dom-server.html)。

现在我们来通过 renderToString 改造一下我们的 server入口文件。

```
// ./src/server/index.tsx
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import Home from "@/pages/Home";

const app = express();
const content = renderToString(<Home />);

app.get("*", (req, res) => {
  res.send(`
    <html
      <body>
        <div>${content}</div>
      </body>
    </html>
  `);
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

刷新一下页面：

![image.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/5573f7909c3c4b3fa16a29197685f9aa~tplv-k3u1fbpfcp-watermark.image?)
可以看到，已经可以渲染出页面，不过按钮上的事件没绑定上去，点 alert 是没有反应的，因为 rendertoString 只是渲染页面，而事件相关的绑定是没办法在服务器端中进行的，那我们怎么才能把事件绑定到静态页面呢？

之前我们有介绍过，掘金也是服务端渲染，我们看看它是怎么做的。

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/caac374cfbd34b8fa47879f1660a5357~tplv-k3u1fbpfcp-watermark.image?)
可以看到，掘金服务端返回的 HTML 文本中包括一组打包过后的 JS，这个其实就是这个页面所对应的相关事件和脚本，我们只需要打包过后将 JS 绑定在 HTML 中就可以。

**这个也叫“同构”，是服务器端渲染的核心概念**，同一套 React 代码在服务器端渲染一遍，然后在客户端再执行一遍。服务端负责静态 dom 的拼接，而客户端负责事件的绑定，不仅是模板页面渲染，后面的路由，数据的请求都涉及到同构的概念。可以理解成，服务器端渲染都是基于同构去展开的，大家这里关注一下这个概念，对后面的学习理解会有很大的帮助

现在我们就开始将模板中的脚本打包引入到 HTML 中，这里我们就要用到`ReactDom.hydrateRoot`了，这个在上面给到的 React官网中也有相关的介绍：

> If you call `ReactDOM.hydrateRoot()` on a node that already has this server-rendered markup, React will preserve it and only attach event handlers, allowing you to have a very performant first-load experience.

在已经提供了服务器端静态渲染节点的情况下使用，它只会对模板中的事件进行处理，这样就可以满足我们的需求了，新增一个 src/client/index.tsx 作为我们客户端页面的构建入口：

```
// src/client/index.tsx

import { hydrateRoot } from "react-dom/client";
import Home from "@/pages/Home";

hydrateRoot(document.getElementById("root") as Document | Element, <Home />);
```

`ReactDom.hydrateRoot` 需要指定一个绑定的真实 dom，我们给 server 入口 send 的页面加一个id ：

```
// src/server/index.tsx
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import Home from "@/pages/Home";

const app = express();
const content = renderToString(<Home />);

app.get("*", (req, res) => {
  res.send(`
    <html
      <body>
        <div id="root">${content}</div>
      </body>
    </html>
  `);
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

这样客户端的部分就改造好了，我们也对应给它配一套 webpack 配置，加上对应的构建命令：

```
// webpack.client.js
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

```
// package.json
"scripts": {
    "start": "npx nodemon --watch src server_build/bundle.js",
    "build:client": "npx webpack build --config ./webpack.client.js --watch",
    "build:server": "npx webpack build --config ./webpack.server.js --watch",
},
```

我们执行一下`npm run build:client` 看看构建结果：

![image.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/6c169c82fba449809d132c6febf040ac~tplv-k3u1fbpfcp-watermark.image?)

可以看到构建成功了，并且页面目录下会生成对应的 build_client/index.js 的构建文件，下一步我们将 index.js 加入到返回的 HTML 中：

```
// ./src/server/index.tsx
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import Home from "@/pages/Home";
import path from "path";

const app = express();
const content = renderToString(<Home />);

app.use(express.static(path.resolve(process.cwd(), "client_build")));

app.get("*", (req, res) => {
  res.send(`
    <html
      <body>
        <div id="root">${content}</div>
        <script src="/index.js"></script>
      </body>
    </html>
  `);
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

在上面的代码中，`app.use(express.static(path.resolve(process.cwd(), "client_build")));`我们将对应的打包文件作为静态文件导入，然后在 script中引入对应的路由访问即可，这时候大家可以运行`npm run start`看一下结果了：

![image.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/c8aabcb9f15745268d7bc7b5cddfe4ca~tplv-k3u1fbpfcp-watermark.image?)
可以看到，已经有对应静态资源的请求了，页面也已经可以绑定事件了，到这里模板页面的渲染就已经完成了。

# 路由的匹配

上面我们只加入了 Home 页面的访问，但是事实上咱们站点不可能只有一个页面，所以我们需要再加上路由的匹配，那我们应该怎么做呢？

上个小标题我们介绍了同构的概念，同构有一个原因是，客户端和服务端的返回需要保持一致，不然会有客户端的报错，页面也没办法正常匹配。所以我们需要同时为客户端和服务端的入口都加上对应的路由配置。

首先我们先安装一下路由相关的依赖：

```
npm install react-router-dom --save
```

再创建一个简单的 demo 模板页面，光只有一个模板页面，路由咱也不太好试验：

```
// ./src/pages/Demo/index.tsx
import { FC } from "react";

const Demo: FC = (data) => {
  return (
    <div>这是一个demo页面</div>
  );
};

export default Demo;
```

然后我们创建一个 router.tsx 来存放路由相关的配置，现在总共有两个路由：

```
// ./src/router.tsx
import Home from "@/pages/Home";
import Demo from "@/pages/Demo";

interface IRouter {
  path: string;
  element: JSX.Element;
}

const router: Array<IRouter> = [
  {
    path: "/",
    element: <Home />,
  },
  {
    path: "/demo",
    element: <Demo />,
  },
];

export default router;
```

接着我们来改造客户端，我们将上面路由的配置遍历一下，塞到对应 Route 节点中：

```
// ./src/client/index.tsx
import { hydrateRoot } from "react-dom/client";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import router from "@/router";

const Client = (): JSX.Element => {
  return (
    <BrowserRouter>
      <Routes>
        {router?.map((item, index) => {
          return <Route {...item} key={index} />;
        })}
      </Routes>
    </BrowserRouter>
  );
};

hydrateRoot(document.getElementById("root") as Document | Element, <Client />);
```

服务端也相同，我们用路由的部分来替换上面固定的`<Home />`：

```
// ./src/server/index.tsx
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import path from "path";
import router from "@/router";
import { Route, Routes } from "react-router-dom";
import { StaticRouter } from "react-router-dom/server";

const app = express();

app.use(express.static(path.resolve(process.cwd(), "client_build")));

app.get("*", (req, res) => {
  const content = renderToString(
    <StaticRouter location={req.path}>
      <Routes>
        {router?.map((item, index) => {
          return <Route {...item} key={index} />;
        })}
      </Routes>
    </StaticRouter>
  );

  res.send(`
    <html
      <body>
        <div id="root">${content}</div>
        <script src="/index.js"></script>
      </body>
    </html>
  `);
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

其中`StaticRouter `是无状态的路由，因为服务器端不同于客户端，客户端中，浏览器历史记录会改变状态，同时将屏幕更新，但是服务器端是不能改动到应用状态的，所以我们这里采用无状态路由。

做完这些路由的改造就完成了，还是很简单的，只是在客户端和服务器端都进行路由配置即可，这时候大家可以重新运行，打开 http://127.0.0.1:3000/demo，可以看到已经可以进行路由匹配了。

![image.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/e8b8585a5d524ff0905ca70d0d8336eb~tplv-k3u1fbpfcp-watermark.image?)
因为存在客户端路由和服务端路由，所以服务器端渲染通过不同的方式跳转也会采用不同的渲染方式，当使用 React 内置的路由跳转的时候，会进行客户端路由的跳转，采用客户端渲染；而通过 a 标签，或者原生方式打开一个新页面的时候，才会进行服务器端路由的跳转，使用服务器端渲染。

我们可以做个小实验来验证一下，改造 home 页面如下：

```
// ./src/pages/Home/index.tsx
import { useNavigate } from "react-router-dom";

const Home = () => {
  const navigate = useNavigate();

  return (
    <div>
      <h1>hello-ssr</h1>
      <button
        onClick={(): void => {
          alert("hello-ssr");
        }}
      >
        alert
      </button>
      <a href="http://127.0.0.1:3000/demo">链接跳转</a>
      <span
        onClick={(): void => {
          navigate("/demo");
        }}
      >
        路由跳转
      </span>
    </div>
  );
};

export default Home;
```

我们加上了两个跳转，刷新页面，当点击“**链接跳转** **”** 的时候，可以看到 network 中会有对服务器端的请求，所以是通过服务器端渲染的页面。

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/dee615f8810544a8b777632ecbb51d7c~tplv-k3u1fbpfcp-watermark.image?)
当我们点击“**路由跳转** **”** 的时候，走的是客户端路由，这时候打开的页面将不是服务器端渲染，而是会走客户端渲染兜底，可以看到 network 中是没有对服务器端的 HTML 请求的。

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/374ed47e47994e0db7160483532563c4~tplv-k3u1fbpfcp-watermark.image?)

# Header 标签的修改

上面我们一起来实践了 SSR 的模板页面的渲染和路由匹配，不过这个还不能满足我们所有静态页面的需求，因为模板页面只是影响到 body 的部分，修改不同路由下对应的标题，多媒体适配或是 SEO 时加入的相关 meta 关键字，都需要加入相关的 header。

![image.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fa55dce108af4e5683ea3d142a4fef80~tplv-k3u1fbpfcp-watermark.image?)
我们进入正题，服务器端渲染怎么才能修改到对应的 header 呢？可以使用 react-helmet 来实现我们的需求，这个依赖支持对文档头进行调整，我们先来安装一下依赖：

```
npm install react-helmet --save
npm install @types/react-helmet --save-dev
```

同样，这个调整是需要同构的，客户端和服务端都要针对性调整，我们先对客户端进行改造，以 Home页举例：

```
// ./src/pages/Home/index.tsx
import { useNavigate } from "react-router-dom";
import { Fragment } from "react";
import { Helmet } from "react-helmet";

const Home = () => {
  const navigate = useNavigate();

  return (
    <Fragment>
      <Helmet>
        <title>简易的服务器端渲染 - HOME</title>
        <meta name="description" content="服务器端渲染"></meta>
      </Helmet>
      <div>
        <h1>hello-ssr</h1>
        <button
          onClick={(): void => {
            alert("hello-ssr");
          }}
        >
          alert
        </button>
        <a href="http://127.0.0.1:3000/demo">链接跳转</a>
        <span
          onClick={(): void => {
            navigate("/demo");
          }}
        >
          路由跳转
        </span>
      </div>
    </Fragment>
  );
};

export default Home;
```

然后我们对服务器端也进行相同的同构，保证服务器端的返回也是相同的 header，这一点很重要，因为大部分搜索引擎的爬虫关键词爬取都是根据服务器返回内容进行关键词检索的。

```
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import path from "path";
import router from "@/router";
import { Route, Routes } from "react-router-dom";
import { StaticRouter } from "react-router-dom/server";
import { Helmet } from "react-helmet";

const app = express();

app.use(express.static(path.resolve(process.cwd(), "client_build")));

app.get("*", (req, res) => {
  const content = renderToString(
    <StaticRouter location={req.path}>
      <Routes>
        {router?.map((item, index) => {
          return <Route {...item} key={index} />;
        })}
      </Routes>
    </StaticRouter>
  );

  const helmet = Helmet.renderStatic();

  res.send(`
    <html
      <head>
        ${helmet.title.toString()}
        ${helmet.meta.toString()}
      </head>
      <body>
        <div id="root">${content}</div>
        <script src="/index.js"></script>
      </body>
    </html>
  `);
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

`Helmet.renderStatic()`可以提供渲染时添加的所有内容，这样我们就已经完成 header 标签的修改了，可以刷新一下页面看一下效果：

![image.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/b43b3830b212463fb9faf28072bb30a4~tplv-k3u1fbpfcp-watermark.image?)

# 小结

这一节课，我们学习了如何实现 SSR 的静态页面渲染，包括模板页面的渲染、路由的匹配和 Header 标签的修改，同时也介绍了服务器端渲染中一个很重要的概念 -- 同构，相信大家学习后对服务器端渲染已经有了一个相对深刻的了解，同学们也可以结合下面画的思维导图回忆温习一下今天的内容，加深对整个过程的理解。

![image.png](http://assets.liyunfu.tech/images/202401261513012.png)

现在我们已经实现了静态页面的部分，但是实际上，并不是所有的数据都是静态的，往往需要通过接口的请求来拿到预期的数据。所以在下节课，我们将来学习，如何支持 SSR 的数据请求。

> 仓库地址：https://github.com/czm1290433700/ssr-server

上一节课我们学习了怎么实现 SSR 的静态页面渲染，但是一个页面不可能只有静态的部分，那么 SSR 中我们应该怎么进行数据的请求和注入呢？我们先做下简单尝试，看能不能直接用平常我们开发的方式来请求。

# hook 请求是否可行？

我们先启一个路由，用来作为一个简单接口，因为 express 没办法直接读取请求的 body，所以我们需要用 body-parser 对请求进行一个解析：

```
npm install body-parser --save
```

```
// ./src/server/index.tsx
// ./src/server/index.tsx
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import path from "path";
import router from "@/router";
import { Route, Routes } from "react-router-dom";
import { StaticRouter } from "react-router-dom/server";
import { Helmet } from "react-helmet";

const app = express();

const bodyParser = require("body-parser");

app.use(express.static(path.resolve(process.cwd(), "client_build")));

// 请求body解析
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// 启一个post服务
app.post("/api/getDemoData", (req, res) => {
  res.send({
    data: req.body,
    status_code: 0,
  });
});

app.get("*", (req, res) => {
  const content = renderToString(
    <StaticRouter location={req.path}>
      <Routes>
        {router?.map((item, index) => {
          return <Route {...item} key={index} />;
        })}
      </Routes>
    </StaticRouter>
  );

  const helmet = Helmet.renderStatic();

  res.send(`
    <html
      <head>
        ${helmet.title.toString()}
        ${helmet.meta.toString()}
      </head>
      <body>
        <div id="root">${content}</div>
        <script src="/index.js"></script>
      </body>
    </html>
  `);
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

然后咱们在 Demo 页面中直接用 hook 来请求，这个过程需要装一下 axios 的依赖：

```
npm install axios --save
```

```
// ./src/pages/Demo/index.tsx
import { FC, useState, useEffect } from "react";
import axios from "axios";

const Demo: FC = (data) => {
  const [content, setContent] = useState("");

  useEffect(() => {
    axios
      .post("/api/getDemoData", {
        content: "这是一个demo页面",
      })
      .then((res: any) => {
        setContent(res.data?.data?.content);
      });
  }, []);

  return <div>{content}</div>;
};

export default Demo;
```

然后我们刷新一下 Demo 页面看看：

<img src="https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/e824dd29b0214eddaf7ea8a1235d3ba0~tplv-k3u1fbpfcp-watermark.image?" alt="image.png"  />
数据请求成功了，不过，不对的是，我们可以在 network 中看到对应的请求，数据也没在服务器端请求的时候塞入 HTML，也就是说走的是客户端渲染，而不是服务端渲染，和我们预期的不一样，看来是不能直接用 hook 来常规请求的。

我们来回忆之前静态页面的思路，是在服务器端拼凑好 HTML 并返回，所以请求的话，咱们应该也是获取到每个模板页面初始化的请求，并在服务器端请求好，进行 HTML 拼凑，在这之前我们需要建立一个全局的 store，使得服务端请求的数据可以提供到模板页面来进行操作。确认好思路，咱们就根据这个思路先来解决试试。

# 全局 store 的建立

store 的建立我们可以基于 redux 去做，redux 是一个可以对 state 进行统一管理的库。全局 store 的核心在于上一章节提到的“同构”，服务器端和客户端都需要建立 store，我们先装一下相关的依赖：

```
npm install @reduxjs/toolkit redux-thunk react-redux --save
```

其中 @reduxjs/toolkit 是 redux 最新提供的工具包，可以用于状态的统一管理，提供了更多 hook 的能力，相对代码更为简易，至于 redux-thunk 是一个 redux 的中间件，提供了 dispatch 和 getState 与异步方法交互的能力。

然后我们在 Demo 页面下创建一个 store 目录，用来存放对应的 reducer，将之前客户端请求的逻辑加进去，并且设置一个默认值“默认数据”，如果请求成功的话，咱们就把传入参数返回一下。

```
// ./src/pages/Demo/store/demoReducer.ts
import { createSlice, createAsyncThunk } from "@reduxjs/toolkit";
import axios from "axios";

const getDemoData = createAsyncThunk(
  "demo/getData",
  async (initData: string) => {
    const res = await axios.post("http://127.0.0.1:3000/api/getDemoData", {
      content: initData,
    });
    return res.data?.data?.content;
  }
);

const demoReducer = createSlice({
  name: "demo",
  initialState: {
    content: "默认数据",
  },
  // 同步reducer
  reducers: {},
  // 异步reducer
  extraReducers(build) {
    build
      .addCase(getDemoData.pending, (state, action) => {
        state.content = "pending";
      })
      .addCase(getDemoData.fulfilled, (state, action) => {
        state.content = action.payload;
      })
      .addCase(getDemoData.rejected, (state, action) => {
        state.content = "rejected";
      });
  },
});

export { demoReducer, getDemoData };
```

createSlice 这个函数我们着重讲一下，因为是 redux 比较新的版本，很多同学可能还是比较陌生的。

- reducers：可以存放同步的 reducers（不需要请求参数）；

<!---->

- initialState：可以理解成原来的 state；

<!---->

- name： 是这个 reducer 的空间，后面取 store 的时候会根据这个进行区分；

<!---->

- extraReducers：这个是我们这里需要的异步 reducer，其中包含三个状态，pending、fulfilled 和 rejected，分别对应到请求的三种状态。

这种函数式的写法可以即用即配，是个不错的改进版本。因为只是一个状态管理的方式，并不是我们这章的重点，更详细的参数和部分大家可以在[ @reduxjs/toolkit 的官网](https://redux-toolkit.js.org/introduction/getting-started)学习了解。

我们还可以创建一个 index.ts 来作为统一导出，因为一个页面可能不只有一个 reducer，这样引用的时候就不用每一个都写一个 import 了，都从 index.ts 中统一导出就可以：

```
// ./src/pages/Demo/store/index.ts
import { demoReducer } from "./demoReducer";

export { demoReducer };
```

然后我们分别创建一下客户端和服务器端的 store，将 reducer 导入一下，并且接入一下 thunk 的中间件，使得 dispatch 相关的函数支持异步函数的入参：

```
// ./src/store/index.ts
import { configureStore } from "@reduxjs/toolkit";
import thunk from "redux-thunk";
import { demoReducer } from "@/pages/Demo/store";

const clientStore = configureStore({
  reducer: { demo: demoReducer.reducer },
  middleware: (getDefaultMiddleware) => getDefaultMiddleware().concat(thunk),
});

const serverStore = configureStore({
  reducer: { demo: demoReducer.reducer },
  middleware: (getDefaultMiddleware) => getDefaultMiddleware().concat(thunk),
});

export { clientStore, serverStore };
```

接下来我们将创建好的 store 分别在客户端和服务器端的路由处注入一下就可以：

```
// ./src/client/index.tsx
import { hydrateRoot } from "react-dom/client";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import router from "@/router";
import { clientStore } from "@/store";
import { Provider } from "react-redux";

const Client = (): JSX.Element => {
  return (
    <Provider store={clientStore}>
      <BrowserRouter>
        <Routes>
          {router?.map((item, index) => {
            return <Route {...item} key={index} />;
          })}
        </Routes>
      </BrowserRouter>
    </Provider>
  );
};

// 将事件处理加到ID为root的dom下
hydrateRoot(document.getElementById("root") as Document | Element, <Client />);
```

```
// ./src/server/index.tsx
import express from "express";
import childProcess from "child_process";
import { renderToString } from "react-dom/server";
import path from "path";
import router from "@/router";
import { Route, Routes } from "react-router-dom";
import { StaticRouter } from "react-router-dom/server";
import { Helmet } from "react-helmet";
import { serverStore } from "@/store";
import { Provider } from "react-redux";

const app = express();

const bodyParser = require("body-parser");

app.use(express.static(path.resolve(process.cwd(), "client_build")));

// 请求body解析
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// 启一个post服务
app.post("/api/getDemoData", (req, res) => {
  res.send({
    data: req.body,
    status_code: 0,
  });
});

app.get("*", (req, res) => {
  const content = renderToString(
    <Provider store={serverStore}>
      <StaticRouter location={req.path}>
        <Routes>
          {router?.map((item, index) => {
            return <Route {...item} key={index} />;
          })}
        </Routes>
      </StaticRouter>
    </Provider>
  );

  const helmet = Helmet.renderStatic();

  res.send(`
    <html
      <head>
        ${helmet.title.toString()}
        ${helmet.meta.toString()}
      </head>
      <body>
        <div id="root">${content}</div>
        <script src="/index.js"></script>
      </body>
    </html>
  `);
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

到这里 store 就已经注入好了，我们只需要在 Demo 中与 store 连接就行。connect 暴露了两个参数，一个 state，一个 dispatch，它会根据你的需要拼接成指定的参数，以装饰器的形式包装你定义的函数，这样我们的 Demo 就可以接收到我们定义的 content 和 getDemoData 参数了。

```
// ./src/pages/Demo/index.tsx
import { FC, useState, useEffect, Fragment } from "react";
import axios from "axios";
import { connect } from "react-redux";
import { getDemoData } from "./store/demoReducer";
import { Helmet } from "react-helmet";

interface IProps {
  content?: string;
  getDemoData?: (data: string) => void;
}

const Demo: FC<IProps> = (data) => {
  // const [content, setContent] = useState("");

  // // 客户端异步请求
  // useEffect(() => {
  //   axios
  //     .post("/api/getDemoData", {
  //       content: "这是一个demo",
  //     })
  //     .then((res) => {
  //       setContent(res.data?.data?.content);
  //     });
  // }, []);

  return (
    <Fragment>
      <Helmet>
        <title>简易的服务器端渲染框架 - DEMO</title>
        <meta name="description" content="服务器端渲染框架"></meta>
      </Helmet>
      <div>
        <h1>{data.content}</h1>
        <button
          onClick={(): void => {
            data.getDemoData && data.getDemoData("刷新过后的数据");
          }}
        >
          刷新
        </button>
      </div>
    </Fragment>
  );
};

const mapStateToProps = (state: any) => {
  // 将对应reducer的内容透传回dom
  return {
    content: state?.demo?.content,
  };
};

const mapDispatchToProps = (dispatch: any) => {
  return {
    getDemoData: (data: string) => {
      dispatch(getDemoData(data));
    },
  };
};

const storeDemo: any = connect(mapStateToProps, mapDispatchToProps)(Demo);

export default storeDemo;
```

到这里我们的全局 store 就建立了，我们可以刷新一下页面试试。

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/864e92b0f62146e18cc961179d126c41~tplv-k3u1fbpfcp-watermark.image?)
可以看到展示的是默认数据，那是因为我们并没有进行初始化的请求，所以它走了默认的 state 兜底，然后我们点击刷新试试。

![image.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/553e74ee93ba4490b286468c9828a252~tplv-k3u1fbpfcp-watermark.image?)
可以看到新增了对应的请求，对应展示的内容也切换为了刷新过后的数据，那这就意味着咱们 store的部分已经走通了，接下来咱们只需要考虑，应该怎样在服务器端进行请求，使得在 html 拼接的时候就可以拿到初始化的数据呢？

# 建立服务器端请求数据体系

需要在服务器端进行初始化，我们先来捋捋思路，首先我们肯定得先在服务器端拿到所有需要请求的函数，怎么透传过去呢？我们应该可以使用路由，因为客户端和服务端咱们都有配置路由，如果加一个参数通过路由把参数透传，然后在服务器端遍历，最后把结果对应分发是不是就可以了。

思路捋好咱们就可以开始做了，不过这里有个小细节大家要注意一下，服务器端不同于客户端，它是拿不到请求的域名的，**所以服务器端下的axios请求应该是包含域名的绝对路径，而不是使用相对路径，很多SSR的初学者在开发过程中很容易遇到类似问题** **。**

好了，进入正题，咱们先给 Demo 定义一个初始化的函数，两个入参，一个透传 store，另一个 data，对应页面展示的内容：

```
// ./src/pages/Demo/index.tsx
import { FC, useState, useEffect, Fragment } from "react";
import axios from "axios";
import { connect } from "react-redux";
import { getDemoData } from "./store/demoReducer";
import { Helmet } from "react-helmet";

interface IProps {
  content?: string;
  getDemoData?: (data: string) => void;
}

const Demo: FC<IProps> = (data) => {
  // const [content, setContent] = useState("");

  // // 客户端异步请求
  // useEffect(() => {
  //   axios
  //     .post("/api/getDemoData", {
  //       content: "这是一个demo",
  //     })
  //     .then((res) => {
  //       setContent(res.data?.data?.content);
  //     });
  // }, []);

  return (
    <Fragment>
      <Helmet>
        <title>简易的服务器端渲染框架 - DEMO</title>
        <meta name="description" content="服务器端渲染框架"></meta>
      </Helmet>
      <div>
        <h1>{data.content}</h1>
        <button
          onClick={(): void => {
            data.getDemoData && data.getDemoData("刷新过后的数据");
          }}
        >
          刷新
        </button>
      </div>
    </Fragment>
  );
};

const mapStateToProps = (state: any) => {
  // 将对应reducer的内容透传回dom
  return {
    content: state?.demo?.content,
  };
};

const mapDispatchToProps = (dispatch: any) => {
  return {
    getDemoData: (data: string) => {
      dispatch(getDemoData(data));
    },
  };
};

const storeDemo: any = connect(mapStateToProps, mapDispatchToProps)(Demo);

storeDemo.getInitProps = (store: any, data?: string) => {
  return store.dispatch(getDemoData(data || "这是初始化的demo"));
};

export default storeDemo;
```

咱们先对路由进行一下改造，将初始化的方法给路由带上：

```
// ./src/router/index.tsx
import Home from "@/pages/Home";
import Demo from "@/pages/Demo";

interface IRouter {
  path: string;
  element: JSX.Element;
  loadData?: (store: any) => any;
}

const router: Array<IRouter> = [
  {
    path: "/",
    element: <Home />,
  },
  {
    path: "/demo",
    element: <Demo />,
    loadData: Demo.getInitProps,
  },
];

export default router;
```

接下来咱们就该在服务器端拉取对应的初始化方法，并统一请求注入它们了，这个过程很简单，我们只需要改造 get 方法就可以，遍历所有的初始化方法，然后统一请求塞进 store 里。

```
// ./src/server/index.tsx
import express from "express";
import childProcess from "child_process";
import path from "path";
import { Route, Routes } from "react-router-dom";
import { renderToString } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import { matchRoutes, RouteObject } from "react-router-dom";
import router from "@/router";
import { serverStore } from "@/store";
import { Provider } from "react-redux";
import { Helmet } from "react-helmet";

const app = express();

const bodyParser = require("body-parser");

// 请求body解析
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// 注入事件处理的脚本
app.use(express.static(path.resolve(process.cwd(), "client_build")));

// demo api
app.post("/api/getDemoData", (req, res) => {
  res.send({
    data: req.body,
    status_code: 0,
  });
});

app.get("*", (req, res) => {
  const routeMap = new Map<string, () => Promise<any>>(); // path - loaddata 的map
  router.forEach((item) => {
    if (item.path && item.loadData) {
      routeMap.set(item.path, item.loadData(serverStore));
    }
  });

  // 匹配当前路由的routes
  const matchedRoutes = matchRoutes(router as RouteObject[], req.path);

  const promises: Array<() => Promise<any>> = [];
  matchedRoutes?.forEach((item) => {
    if (routeMap.has(item.pathname)) {
      promises.push(routeMap.get(item.pathname) as () => Promise<any>);
    }
  });

  Promise.all(promises).then((data) => {
    // 统一放到state里
    // 编译需要渲染的JSX, 转成对应的HTML STRING
    const content = renderToString(
      <Provider store={serverStore}>
        <StaticRouter location={req.path}>
          <Routes>
            {router?.map((item, index) => {
              return <Route {...item} key={index} />;
            })}
          </Routes>
        </StaticRouter>
      </Provider>
    );

    const helmet = Helmet.renderStatic();

    res.send(`
    <html
      <head>
        ${helmet.title.toString()}
        ${helmet.meta.toString()}
      </head>
      <body>
        <div id="root">${content}</div>
        <script>
          window.context = {
            state: ${JSON.stringify(serverStore.getState())}
          }
        </script>
        <script src="/index.js"></script>
      </body>
    </html>
  `);
  });
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

到这里服务器端请求就走通了，我们重启项目访问一下 Demo 页面试试：

![image.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7cb04622b30240b58c65743057eee21a~tplv-k3u1fbpfcp-watermark.image?)
但是很奇怪的是，可以看到服务器端的返回其实是符合预期的，是“这是初始化的demo"，但是页面展示的时候却是默认数据，这是为什么呢？

其实很简单，因为客户端和服务器端的 store 是不同步的，服务器端请求完成填充 store 后，客户端的 JS 又执行了一遍 store，取了默认的值，所以导致数据不能同步。要解决这个问题，就需要使用脱水和注水的方式。

# 脱水和注水

水在这里其实就是数据层，也就是 store，这里对客户端页面进行脱“水”，移除其数据层的部分，仅仅保留 dom 的部分，然后在服务器端请求拿到 store 以后，对数据进行注入，也就是注“水”，使得客户端的数据与服务端请求的数据保持一致，就可以解决掉不同步的问题了。

我们首先在服务器端，将“水”注入到客户端脚本中：

```
// ./src/server/index.tsx
import express from "express";
import childProcess from "child_process";
import path from "path";
import { Route, Routes } from "react-router-dom";
import { renderToString } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import { matchRoutes, RouteObject } from "react-router-dom";
import router from "@/router";
import { serverStore } from "@/store";
import { Provider } from "react-redux";
import { Helmet } from "react-helmet";

const app = express();

const bodyParser = require("body-parser");

// 请求body解析
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// 注入事件处理的脚本
app.use(express.static(path.resolve(process.cwd(), "client_build")));

// demo api
app.post("/api/getDemoData", (req, res) => {
  res.send({
    data: req.body,
    status_code: 0,
  });
});

app.get("*", (req, res) => {
  const routeMap = new Map<string, () => Promise<any>>(); // path - loaddata 的map
  router.forEach((item) => {
    if (item.path && item.loadData) {
      routeMap.set(item.path, item.loadData(serverStore));
    }
  });

  // 匹配当前路由的routes
  const matchedRoutes = matchRoutes(router as RouteObject[], req.path);

  const promises: Array<() => Promise<any>> = [];
  matchedRoutes?.forEach((item) => {
    if (routeMap.has(item.pathname)) {
      promises.push(routeMap.get(item.pathname) as () => Promise<any>);
    }
  });

  Promise.all(promises).then((data) => {
    // 统一放到state里
    // 编译需要渲染的JSX, 转成对应的HTML STRING
    const content = renderToString(
      <Provider store={serverStore}>
        <StaticRouter location={req.path}>
          <Routes>
            {router?.map((item, index) => {
              return <Route {...item} key={index} />;
            })}
          </Routes>
        </StaticRouter>
      </Provider>
    );

    const helmet = Helmet.renderStatic();

    // 注水
    res.send(`
    <html
      <head>
        ${helmet.title.toString()}
        ${helmet.meta.toString()}
      </head>
      <body>
        <div id="root">${content}</div>
        <script>
          window.context = {
            state: ${JSON.stringify(serverStore.getState())}
          }
        </script>
        <script src="/index.js"></script>
      </body>
    </html>
  `);
  });
});

app.listen(3000, () => {
  console.log("ssr-server listen on 3000");
});

childProcess.exec("start http://127.0.0.1:3000");
```

接下来我们在客户端处，Demo 的初始值中注入服务器端的值，这里需要做一个判断，因为服务器端下访问的时候是没有 window 等 BOM 的，所以需要用 typeof 来判断。**这也是SSR中常常遇到的问题，当有对 BOM的调用时，需要进行判空，否则在服务器端执行的时候将会报错。**

```
// ./src/pages/Demo/store/demoReducer.ts
import { createSlice, createAsyncThunk } from "@reduxjs/toolkit";
import axios from "axios";

const getDemoData = createAsyncThunk(
  "demo/getData",
  async (initData: string) => {
    const res = await axios.post("http://127.0.0.1:3000/api/getDemoData", {
      content: initData,
    });
    return res.data?.data?.content;
  }
);

const demoReducer = createSlice({
  name: "demo",
  initialState:
    typeof window !== "undefined"
      ? (window as any)?.context?.state?.demo
      : {
          content: "默认数据",
        },
  // 同步reducer
  reducers: {},
  // 异步reducer
  extraReducers(build) {
    build
      .addCase(getDemoData.pending, (state, action) => {
        state.content = "pending";
      })
      .addCase(getDemoData.fulfilled, (state, action) => {
        state.content = action.payload;
      })
      .addCase(getDemoData.rejected, (state, action) => {
        state.content = "rejected";
      });
  },
});

export { demoReducer, getDemoData };
```

然后我们再重新刷新一下页面看看效果，应该就可以了：

![image.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/d83e53f2ab6e4156af6b5dc4539f1dab~tplv-k3u1fbpfcp-watermark.image?)

# 小结

这一章节我们学习了 SSR 如何针对数据进行请求，在建立了一个全局的 store 后，将对应的初始化方法透传给服务端进行统一请求，最后再进行数据脱水和注水的操作，使得客户端初始化能和服务器端保持相同的 store，整个过程还是有很多细节的，到这里我们 SSR 的实现篇就结束了。

对一个成熟的 SSR 框架还会有更多的处理，类似 CSS、中间件以及注入函数的装饰器包装，不过这些和基础的原理并没有太大的关系，所以在小册中并不会涉及，感兴趣的同学可以下来了解，对整体的代码风格也是有帮助的。

设立实现篇的初衷，是希望大家可以清楚其中页面渲染到数据请求的过程中是怎么流转的，这样在后期开发中，面对路由跳转，或是请求等不同于客户端的地方时，能知道原理以及为什么产生这些区别，如果三节课学习下来有一点不太理解，大家也不用着急，可以沉下心来多看几遍，涉及的知识点的确不少，如果能完全理解这三节的原理，对大家后面实战的学习会有很大帮助。

从下一节课开始，我们将进入实战的学习，如何使用业内比较成熟的框架 Next.js 来开发一个官网项目？
