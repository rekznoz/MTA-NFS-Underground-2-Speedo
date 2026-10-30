texture gTexture;
float gLevel = 0;
float gStartAngle = 0;
float gSweepAngle = 3.14159265;
float2 gPivot = float2(0.5, 0.5);
float gFullTextureAtMax = 0;

sampler TextureSampler = sampler_state
{
    Texture = <gTexture>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

float4 radialFill(float2 uv : TEXCOORD0, float4 diffuse : COLOR0) : COLOR0
{
    float2 offset = uv - gPivot;
    float angle = atan2(offset.x, -offset.y);
    float sweep = frac((angle - gStartAngle) / 6.28318530718 + 1.0) * 6.28318530718;
    float progress = sweep / gSweepAngle;
    float visible = 1.0 - smoothstep(gLevel - 0.003, gLevel + 0.003, progress);
    visible *= progress <= 1.0 ? 1.0 : 0.0;
    visible = gLevel <= 0.0002 ? 0.0 : visible;
    visible = gFullTextureAtMax > 0.5 && gLevel >= 0.9998 ? 1.0 : visible;
    float4 color = tex2D(TextureSampler, uv) * diffuse;
    color.a *= visible;
    return color;
}

technique RadialFill
{
    pass P0
    {
        PixelShader = compile ps_2_0 radialFill();
    }
}
