// Explicit Odin runtime imports let Emscripten reject every other missing symbol.
// The HTML host provides these same functions to the odin_env Wasm import module.
addToLibrary({
  write: function(fd, pointer, length) {
    return Module.odinImports.odin_env.write(fd, pointer, length);
  },
  rand_bytes: function(pointer, length) {
    return Module.odinImports.odin_env.rand_bytes(pointer, length);
  }
});
