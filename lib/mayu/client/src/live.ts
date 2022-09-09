import init from "./Mayu.js";

const MAYU_INIT = "mayu-init";
const mayuInit = document.getElementById(MAYU_INIT);

if (!mayuInit) {
  alert("Could not init app!");
  throw new Error(`Element with id ${MAYU_INIT} not found`);
}

const encryptedState = (mayuInit as HTMLTemplateElement).content.textContent;
mayuInit.remove();
init(encryptedState);
