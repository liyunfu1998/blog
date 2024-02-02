---
title: 手动搭建一个SSR mvp项目
description: 手动搭建一个SSR mvp项目
pubDatetime: 2024-01-15T15:11:00Z
slug: ssr-mvp
---

> 大家好，我是点外卖也分期的李一疯，今天带来最近[SSR 实战：官网开发指南 - 祯民 - 掘金小册 (juejin.cn)](https://juejin.cn/book/7137945369635192836?utm_source=course_list)学习SSR相关收获

## 手动搭一个SSR项目

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
