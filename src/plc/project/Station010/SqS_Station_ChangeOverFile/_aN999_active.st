// Finish step: release our HMI requests before reporting completion.
// The existing cancel/error callbacks also call the same _reset method.
_reset();
_env.ChainControl := OpconChainControl.DONE;
