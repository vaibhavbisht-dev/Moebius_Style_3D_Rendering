using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class MoebiusHatchFeature : ScriptableRendererFeature
{
    class MoebiusHatchPass : ScriptableRenderPass
    {
        private Material hatchMaterial;

        public MoebiusHatchPass(Material material)
        {
            hatchMaterial = material;
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing - 1;

            // FIX: Force URP to generate Depth & Normals for this pass!
            ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);
        }

        private class PassData
        {
            public Material material;
            public TextureHandle source;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var resourceData = frameData.Get<UniversalResourceData>();
            var cameraData = frameData.Get<UniversalCameraData>();

            if (hatchMaterial == null) return;

            TextureHandle source = resourceData.activeColorTexture;
            RenderTextureDescriptor desc = cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;

            TextureHandle tempDestination = renderGraph.CreateTexture(new TextureDesc(desc.width, desc.height)
            {
                colorFormat = desc.graphicsFormat,
                name = "MoebiusHatchTemp"
            });

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Moebius Hatch Effect", out var passData))
            {
                passData.material = hatchMaterial;
                passData.source = source;

                builder.UseTexture(source, AccessFlags.Read);

                // FIX: Explicitly tell Render Graph our HLSL shader needs to read these
                if (resourceData.cameraDepthTexture.IsValid())
                    builder.UseTexture(resourceData.cameraDepthTexture, AccessFlags.Read);
                if (resourceData.cameraNormalsTexture.IsValid())
                    builder.UseTexture(resourceData.cameraNormalsTexture, AccessFlags.Read);

                builder.SetRenderAttachment(tempDestination, 0, AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    Blitter.BlitTexture(context.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Moebius Hatch Blit Back", out var passData))
            {
                passData.source = tempDestination;
                builder.UseTexture(tempDestination, AccessFlags.Read);
                builder.SetRenderAttachment(source, 0, AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    Blitter.BlitTexture(context.cmd, data.source, new Vector4(1, 1, 0, 0), 0.0f, false);
                });
            }
        }
    }

    public Material postProcessMaterial;
    private MoebiusHatchPass customPass;

    public override void Create()
    {
        customPass = new MoebiusHatchPass(postProcessMaterial);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (postProcessMaterial != null && renderingData.cameraData.cameraType != CameraType.Preview)
            renderer.EnqueuePass(customPass);
    }
}