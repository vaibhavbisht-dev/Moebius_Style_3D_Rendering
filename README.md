Moebius Stylized Outline & Hatching - Unity URP
===============================================

Overview
--------
This Unity project provides a set of screen-space and object-space stylized rendering effects for the Universal Render Pipeline (URP). It includes a Moebius-style outline pass and a cross-hatch post-processing pass implemented as shaders plus small render feature scripts to integrate them into URP. `*This Projecct is Inspired From Useless Game Dev's Moebius-style 3D Rendering video.*`

Key Features
------------
- Stylized outline rendering for objects.
- Screen-space cross-hatch post-process with controllable tiling, intensity and specular cutoff.
- Designed for URP (Universal Render Pipeline).

Included files
--------------
- `Assets/RenderFeature/MoebiusOutlineFeature.cs` - URP render feature to inject the outline pass.
- `Assets/RenderFeature/MoebiusHatchFeature.cs` - URP render feature to inject the hatching post-process.
- `Assets/Shader/MoebiusOutline.shader` - Shader used by the outline render pass.
- `Assets/Shader/MoebiusObject.shader` - Object-space shader variant used by some materials.
- `Assets/Shader/MoebiusHatch.shader` - Screen-space post-process shader that applies cross-hatch stylization.

Shader properties (high level)
------------------------------
- `MoebiusHatch` shader
  - `_HatchTex` — cross-hatch lookup texture (RGB typically stores different line directions). 
  - `_HatchTiling` — controls UV scale of hatch texture.
  - `_HatchIntensity` — how strong the hatch darkening is (0 = no hatch, 1 = full hatch).
  - `_SpecularThreshold` — threshold above which specular highlights are preserved.

- `MoebiusOutline` / `MoebiusObject` shaders
  - Outline color / thickness properties (see shader source for exact names).

Installation
------------
1. Use Unity with the Universal Render Pipeline (URP) configured for your project.
2. Copy or import the `Assets` folder contents into your project.
3. In your URP Renderer asset, add the provided render feature scripts (`MoebiusOutlineFeature` and/or `MoebiusHatchFeature`) to the renderer's Render Features list.
4. Assign required references (hatch texture, materials) and tweak properties in the render feature inspector.

Usage tips
----------
- Use a small seamless cross-hatch texture (RGB channels can encode horizontal, vertical, diagonal line patterns).
- Adjust `_HatchTiling` to change line density.
- Reduce `_HatchIntensity` if hatched lines appear too dark.
- To avoid applying the hatch to skybox/clear regions the shader samples scene depth and normals.

Extending
---------
- The render features are simple and intended as a starting point — you can add filtering, color grading, or blend modes.
- For GPU performance tuning, consider using lower-resolution render targets for the hatch pass or adjusting sample counts.

License & Attribution
---------------------
- This repository contains shader and C# code. Verify and adapt any licensing needs before reusing in production.

Contact / Notes
---------------
- These files are intended for integration with Unity URP. If you need help adapting to HDRP or built-in pipeline, the shader logic and render-feature approach will need changes.

