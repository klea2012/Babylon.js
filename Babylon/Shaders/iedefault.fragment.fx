﻿#ifdef GL_ES
precision mediump float;
#endif

#define MAP_PROJECTION	4.

// Constants
uniform vec3 vEyePosition;
uniform vec3 vAmbientColor;
uniform vec4 vDiffuseColor;
uniform vec4 vSpecularColor;
uniform vec3 vEmissiveColor;
uniform vec4 vMisc;
uniform vec4 vLightsType;

// Lights
#ifdef LIGHT0
uniform vec3 vLightData0;
uniform vec3 vLightDiffuse0;
uniform vec3 vLightSpecular0;
#endif

// Samplers
#ifdef DIFFUSE
varying vec2 vDiffuseUV;
uniform sampler2D diffuseSampler;
uniform vec2 vDiffuseInfos;
#endif

#ifdef AMBIENT
varying vec2 vAmbientUV;
uniform sampler2D ambientSampler;
uniform vec2 vAmbientInfos;
#endif

#ifdef OPACITY	
varying vec2 vOpacityUV;
uniform sampler2D opacitySampler;
uniform vec2 vOpacityInfos;
#endif

#ifdef REFLECTION
varying vec3 vReflectionUVW;
uniform samplerCube reflectionCubeSampler;
uniform sampler2D reflection2DSampler;
uniform vec2 vReflectionInfos;
#endif

#ifdef EMISSIVE
varying vec2 vEmissiveUV;
uniform vec2 vEmissiveInfos;
uniform sampler2D emissiveSampler;
#endif

#ifdef SPECULAR
varying vec2 vSpecularUV;
uniform vec2 vSpecularInfos;
uniform sampler2D specularSampler;
#endif

// Input
varying vec3 vPositionW;
varying vec3 vNormalW;

#ifdef CLIPPLANE
varying float fClipDistance;
#endif

void main(void) {
	// Clip plane
#ifdef CLIPPLANE
	if (fClipDistance > 0.0)
		discard;
#endif

	vec3 viewDirectionW = normalize(vEyePosition - vPositionW);

	// Base color
	vec4 baseColor = vec4(1., 1., 1., 1.);
	vec3 diffuseColor = vDiffuseColor.rgb;

#ifdef DIFFUSE
	baseColor = texture2D(diffuseSampler, vDiffuseUV);

#ifdef ALPHATEST
	if (baseColor.a < 0.4)
		discard;
#endif

	baseColor.rgb *= vDiffuseInfos.y;
#endif

	// Ambient color
	vec3 baseAmbientColor = vec3(1., 1., 1.);

#ifdef AMBIENT
	baseAmbientColor = texture2D(ambientSampler, vAmbientUV).rgb * vAmbientInfos.y;
#endif

	// Lighting
	vec3 diffuseBase = vec3(0., 0., 0.);
	vec3 specularBase = vec3(0., 0., 0.);

#ifdef LIGHT0
	vec3 lightVectorW;
	if (vLightsType.x == 0.)
	{
		lightVectorW = normalize(vLightData0 - vPositionW);
	}
	else 
	{
		lightVectorW = normalize(-vLightData0);
	}

	// diffuse
	float ndl = max(0., dot(vNormalW, lightVectorW));

	// Specular
	vec3 angleW = normalize(viewDirectionW + lightVectorW);
	float specComp = dot(normalize(vNormalW), angleW);
	specComp = pow(specComp, vSpecularColor.a);

	specularBase += ndl * vLightDiffuse0;
	diffuseBase += specComp * vLightSpecular0;
#endif

	// Reflection
	vec3 reflectionColor = vec3(0., 0., 0.);

#ifdef REFLECTION
	if (vMisc.x != 0.0)
	{
		reflectionColor = textureCube(reflectionCubeSampler, vReflectionUVW).rgb * vReflectionInfos.y;
	}
	else
	{
		vec2 coords = vReflectionUVW.xy;

		if (vReflectionInfos.x == MAP_PROJECTION)
		{
			coords /= vReflectionUVW.z;
		}

		coords.y = 1.0 - coords.y;

		reflectionColor = texture2D(reflection2DSampler, coords).rgb * vReflectionInfos.y;
	}	
#endif

	// Alpha
	float alpha = vDiffuseColor.a;

#ifdef OPACITY
	vec3 opacityMap = texture2D(opacitySampler, vOpacityUV).rgb * vec3(0.3, 0.59, 0.11);
	alpha *= (opacityMap.x + opacityMap.y + opacityMap.z )* vOpacityInfos.y;
#endif

	// Emissive
	vec3 emissiveColor = vEmissiveColor;
#ifdef EMISSIVE
	emissiveColor += texture2D(emissiveSampler, vEmissiveUV).rgb * vEmissiveInfos.y;
#endif

	// Specular map
	vec3 specularColor = vSpecularColor.rgb;
#ifdef SPECULAR
	specularColor = texture2D(specularSampler, vSpecularUV).rgb * vSpecularInfos.y;	
#endif

	// Composition
	vec3 finalDiffuse = clamp(diffuseBase * diffuseColor + emissiveColor + vAmbientColor, 0.0, 1.0) * baseColor.rgb;
	vec3 finalSpecular = specularBase * specularColor;

	gl_FragColor = vec4(finalDiffuse * baseAmbientColor + finalSpecular + reflectionColor, alpha);
}