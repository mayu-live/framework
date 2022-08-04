const template = document.createElement("template");

template.innerHTML = `
<style>
dialog {
  border: 3px solid #c00;
  border-radius: 3px;
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  margin:0;
  background: #fff;
  padding: 0 1em;
  font-size: 1rem;
  box-shadow: rgba(0, 0, 0, 0.25) 0px 54px 55px, rgba(0, 0, 0, 0.12) 0px -12px 30px, rgba(0, 0, 0, 0.12) 0px 4px 6px, rgba(0, 0, 0, 0.17) 0px 12px 13px, rgba(0, 0, 0, 0.09) 0px -3px 5px;
  font-size: 1.2rem;
  user-select: none;
}
h1 {
  font-family: system-ui;
  font-size: 1.6em;
}
p {
  font-family: system-ui;
  font-size: 1em;
}
</style>
<dialog>
<h1>Connection lost</h1>
<p>Please check your internet connection.<p>
<p><a href="javascript:document.location.reload()">Reload the page</a></p>
</dialog>`;

class DisconnectedComponent extends HTMLElement {
  dialog?: HTMLDialogElement

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(template.content.cloneNode(true)) as DocumentFragment

    this.dialog = this.shadowRoot!.querySelector('dialog') as HTMLDialogElement

    this.dialog?.showModal()
  }

  disconnectedCallback() {
    this.dialog?.close()
  }
}

export default DisconnectedComponent
