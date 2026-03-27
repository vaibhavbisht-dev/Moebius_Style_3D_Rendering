using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class MoebiusOutlineFeature : ScriptableRendererFeature
{
    class MoebiusOutlinePass : ScriptableRenderPass
    {
        private Material outlineMaterial;

        public MoebiusOutlinePass(Material material)
        {
            outlineMaterial = material;
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

            // FIX: Force URP to generate Depth & Normals!
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

            if (outlineMaterial == null) return;

            TextureHandle source = resourceData.activeColorTexture;
            RenderTextureDescriptor desc = cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;

            TextureHandle tempDestination = renderGraph.CreateTexture(new TextureDesc(desc.width, desc.height)
            {
                colorFormat = desc.graphicsFormat,
                name = "MoebiusOutlineTemp"
            });

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Moebius Outline Effect", out var passData))
            {
                passData.material = outlineMaterial;
                passData.source = source;

                builder.UseTexture(source, AccessFlags.Read);

                // FIX: Explicitly register dependencies
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

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Moebius Outline Blit Back", out var passData))
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
    private MoebiusOutlinePass customPass;

    public override void Create()
    {
        customPass = new MoebiusOutlinePass(postProcessMaterial);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (postProcessMaterial != null && renderingData.cameraData.cameraType != CameraType.Preview)
            renderer.EnqueuePass(customPass);
    }
}