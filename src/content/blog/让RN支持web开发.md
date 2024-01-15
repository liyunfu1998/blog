---
title: 让React Native支持web
description: 让React Native支持web开发，减少原生环境配置
pubDatetime: 2024-01-15T15:11:00Z
modDatetime: 2023-01-15T15:15:00Z
author: 李云富
slug: react-native-support-web
featured: true
draft: false
tags: ["React Native", "React"]
ogImage: "https://astro-paper.pages.dev/_astro/AstroPaper-v4.E8pWr1CH_Zmry1N.webp.webp"
canonicalURL: "https://blog.liyunfu.tech/posts/react-native-support-web"
---

## 背景

- 为什么不直接开发Web？
- 纯前端不香吗？
- 为什么RN开发不直接用Expo
- React Native for Web不是有官方文档吗？

因为：

- 用了Expo确实好用，但是为了后面的面试之类的，还是原生环境搭建使用吧，毕竟Zustand等这么流行了，面试的时候还是Redux、Mobx，不是我不想用Expo，而是没办法
- 所以为啥不直接开发Web呢，RN只做ios和Android，因为公司垃圾电脑，跑模拟器太卡，摸鱼想学点东西，所以需要RN接入Web，更方便
- 纯前端不香吗？跨端技术终究是要学的，Flutter也学过一段时间，最后还是选择RN，因为公司封装的也类似RN的
- 官方文档不好用，看不懂，无从下手

## 操作

### 第一步：使用npx新建一个RN项目，不要再使用过时的全局Cli了

```js
npx react-native init rnweb
cd rnweb
```

### 第二步：调整初始化项目

```js
mkdir src
mkdir public

touch public/index.html
mv App.js src
mv app.json src
cp index.js src
mv index.js index.native.js
```

### 第三步：安装相关依赖

```js
yarn add react-dom react-native-web
yarn add react-scripts -D
```

### 第四步：修改第二步创建的index.html

```html
// public/index.html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width" />
    <title>Demo Project</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
```

### 第五步：修改`index.native.js`

```js
import { AppRegistry } from "react-native";
import App from "./src/App";
import { name as appName } from "./src/app.json";

AppRegistry.registerComponent(appName, () => App);
```

### 第六步：修改`src/index.js`用作web的入口

```js
import { AppRegistry } from "react-native";
import App from "./App";

AppRegistry.registerComponent("App", () => App);
AppRegistry.runApplication("App", { rootTag: document.getElementById("root") });
```

### 第七步：修改`src/App.js`

```js
import React from "react";
import { SafeAreaView, StatusBar, Text, View } from "react-native";

const App = () => {
  return (
    <SafeAreaView>
      <StatusBar />
      <View>
        <Text style={{ fontSize: 24 }}>Hello World</Text>
      </View>
    </SafeAreaView>
  );
};

export default App;
```

### 第八步：修改`package.json`启动命令

```json
"web": "react-scripts start"
```

> 到此就可`yarn web`启动项目，并在localhost:3000访问了，推荐使用github的codespaces，非常好用速度速度很快
