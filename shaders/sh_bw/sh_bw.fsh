//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

void main()
{
    vec4 c = texture2D( gm_BaseTexture, v_vTexcoord );
    float l = (c.r*2.0 + c.g*3.0 + c.b*1.0)/6.0;
    gl_FragColor = vec4(l, l, l, c.a);
}
