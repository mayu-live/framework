let transferState: Blob | null = null

export function setTransferState(state: Blob | null) {
  transferState = state;
}

export function getTransferState(): Blob | null {
  return transferState
}
