import init from "./Mayu.js";

const { url } = import.meta;

init(url.slice(url.lastIndexOf("#") + 1));
