@echo off
"%VULKAN_SDK%/Bin32/glslangValidator.exe" -V triangle.vert -o triangle_vert.spv
"%VULKAN_SDK%/Bin32/glslangValidator.exe" -V triangle.frag -o triangle_frag.spv
for %%f in (*.spv) do (
  spirv-opt --strip-debug --unify-const --flatten-decorations --eliminate-dead-const %%f -o %%f
)
copy /y triangle_vert.spv ..\..\..\..\assets\shaders\triangle\triangle_vert.spv
copy /y triangle_frag.spv ..\..\..\..\assets\shaders\triangle\triangle_frag.spv
del /f /q *.spv

