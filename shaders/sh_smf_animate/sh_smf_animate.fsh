/*////////////////////////////////////////////////////////////////////////
	SMF animation fragment shader
	This is the standard shader that comes with the SMF system.
	This does some basic diffuse, specular and rim lighting.
*/////////////////////////////////////////////////////////////////////////
varying vec2 v_vTexcoord;
varying vec3 v_vWorldPos;
varying vec3 v_vCamPos;

#define gm_FogStart 0.0
#define gm_RcpFogRange 300.0
#define gm_FogColour vec4(0.06666, 0.06666, 0.06666, 1.0)

void main() {
	float dist = length(v_vWorldPos - v_vCamPos);
	float fogmix = clamp((dist - gm_FogStart) / gm_RcpFogRange, 0.0, 1.0);
    gl_FragColor = mix(texture2D(gm_BaseTexture, v_vTexcoord), gm_FogColour, fogmix);

	//gl_FragColor.rgb *= max(pow(max(v_vNormal.z, 0.0), 0.1), 0.5);

	//Diffuse shade
	//gl_FragColor.rgb *= .5 + .7 * max(dot(v_vNormal, normalize(vec3(1.))), 0.);

	//Specular highlights
	//gl_FragColor.rgb += .1 * pow(max(dot(normalize(reflect(v_eyeVec, v_vNormal)), normalize(vec3(1.))), 0.), 4.);

	//Rim lighting
	//gl_FragColor.rgb += .1 * vec3(pow(1. + v_vRim, 2.));
}