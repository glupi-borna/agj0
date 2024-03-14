//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

void main()
{
    gl_FragColor = vec4(v_vColour.rgb, v_vColour.a * texture2D( gm_BaseTexture, v_vTexcoord ).a);
}
