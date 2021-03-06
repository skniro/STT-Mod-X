#version 120

/*
 _______ _________ _______  _______  _ 
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _ 
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/




/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SHADOW_MAP_BIAS 0.80

#define ENABLE_SOFT_SHADOWS


#define GOD_RAYS
	const float gr_density = 0.8;
	const int 	gr_samples = 15;
	const float gr_noise = 1.0;
	
#define GODRAY_LENGTH 0.65

#define ATMOSPHERIC_FOG

#define VOLUMETRIC_CLOUDS	//Only enable one kind of VOLUMETRIC CLOUDS.
	//#define Three_Clouds		//From SEUS O1
	#define New_Clouds			//From Continuum shaders v1.2.1
	
/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const int 		shadowMapResolution 	= 4096;
const float 	shadowDistance 			= 540.0f;
const float 	shadowIntervalSize 		= 1.0f;
const bool 		shadowHardwareFiltering0 = true;

const bool 		shadowtex1Mipmap = true;
const bool 		shadowtex1Nearest = true;
const bool 		shadowcolor0Mipmap = true;
const bool 		shadowcolor0Nearest = false;
const bool 		shadowcolor1Mipmap = true;
const bool 		shadowcolor1Nearest = false;

const int 		RA8 					= 0;
const int 		RGA8 					= 0;
const int 		RGBA8 					= 1;
const int 		RGBA16 					= 1;
const int 		gcolorFormat 			= RGBA16;
const int 		gdepthFormat 			= RGBA8;
const int 		gnormalFormat 			= RGBA16;
const int 		compositeFormat 		= RGBA8;

const float 	eyeBrightnessHalflife 	= 10.0f;
const float 	centerDepthHalflife 	= 2.0f;
const float 	wetnessHalflife 		= 100.0f;
const float 	drynessHalflife 		= 40.0f;

const int 		superSamplingLevel 		= 0;

const float		sunPathRotation 		= -40.0f;
const float 	ambientOcclusionLevel 	= 0.5f;

const int 		noiseTextureResolution  = 64;


//END OF INTERNAL VARIABLES//

/* DRAWBUFFERS:013 */

const bool gaux1MipmapEnabled = true;
const bool gaux2MipmapEnabled = true;

#define BANDING_FIX_FACTOR 1.0f

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2DShadow shadow;
//uniform sampler2D shadowcolor;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 upVector;

uniform int worldTime;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform vec3 skyColor;

uniform int   isEyeInWater;
uniform float eyeAltitude;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int   fogMode;


varying float timeSunriseSunset;
varying float timeSunset;
varying float timeSunrise;
varying float timeNoon;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorSunglow;
varying vec3 colorBouncedSunlight;
varying vec3 colorScatteredSunlight;
varying vec3 colorTorchlight;
varying vec3 colorWaterMurk;
varying vec3 colorWaterBlue;
varying vec3 colorSkyTint;

uniform int heldBlockLightValue;


/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*-------------------------------------*/
float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;
/*----------------------------*/
float time = float(worldTime);

float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 2000.0)/2000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 2000.0)) / 2000.0) - ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0);
float TimeSunset   = ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

float transition_fading = 1.0-(clamp((timefract-12000.0)/300.0,0.0,1.0)-clamp((timefract-13000.0)/300.0,0.0,1.0) + clamp((timefract-22800.0)/200.0,0.0,1.0)-clamp((timefract-23400.0)/200.0,0.0,1.0));
/*----------------------------*/
float pixeldepth = texture2D(depthtex0,texcoord.xy).x;

vec2 newtc = texcoord.xy;
vec2 texel = vec2(1.0/viewWidth,1.0/viewHeight);

vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
vec3 aux = texture2D(gaux1, texcoord.st).rgb;
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;
vec3 color = texture2D(gcolor, newtc.st).rgb;

float hand = float(aux.g > 0.75 && aux.g < 0.85);
/*----------------------------*/
float matflag = texture2D(gaux1,texcoord.xy).g;
/*----------------------------*/
float pw = 1.0/ viewWidth *4;
float ph = 1.0/ viewHeight *4;
/*----------------------------*/
float readDepth( vec2 coord );
float readDepth(vec2 coord) {
	return 2.0 * near * far / (far + near - (2.0 * texture2D(depthtex0, coord).x - 1.0) * (far - near));
}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float edepth(vec2 coord) {
	return texture2D(depthtex0,coord).z;
}

float hash( float n ) {
	return fract(sin(n)*43758.5453);
}

float noise( in vec2 x ) {
	vec2 p = floor(x);
	vec2 f = fract(x);
	f = f*f*(3.0-2.0*f);
	float n = p.x + p.y*57.0;
	float res = mix(mix( hash(n+  0.0), hash(n+  1.0),f.x), mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y);
	return res;
}


/*-------------------------------------*/

//Get gbuffer textures
vec3  	GetAlbedoLinear(in vec2 coord) {			//Function that retrieves the diffuse texture and convert it into linear space.
	return pow(texture2D(gcolor, coord).rgb, vec3(2.2f));	
}

vec3  	GetAlbedoGamma(in vec2 coord) {			//Function that retrieves the diffuse texture and leaves it in gamma space.
	return texture2D(gcolor, coord).rgb;	
}

vec3  	GetNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return texture2DLod(gnormal, coord.st, 0).rgb * 2.0f - 1.0f;
}

float 	GetDepth(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return texture2D(gdepthtex, coord).r;
}

float 	GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

float 	ExpToLinearDepth(in float depth)
{
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}


//Lightmaps
float 	GetLightmapTorch(in vec2 coord) {			//Function that retrieves the lightmap of light emitted by emissive blocks like torches and lava
	float lightmap = texture2D(gdepth, coord).g;

	//Apply inverse square law and normalize for natural light falloff
	lightmap 		= clamp(lightmap * 1.22f, 0.0f, 1.0f);
	lightmap 		= 1.0f - lightmap;
	lightmap 		*= 5.6f;
	lightmap 		= 1.0f / pow((lightmap + 0.8f), 2.0f);
	lightmap 		-= 0.02435f;

	// if (lightmap <= 0.0f)
		// lightmap = 1.0f;

	lightmap 		= max(0.0f, lightmap);
	lightmap 		*= 0.008f;
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	lightmap 		= pow(lightmap, 0.9f);
	return lightmap;


}

float 	GetLightmapSky(in vec2 coord) {			//Function that retrieves the lightmap of light emitted by the sky. This is a raw value from 0 (fully dark) to 1 (fully lit) regardless of time of day
	return pow(texture2D(gdepth, coord).b, 4.3f);
}

float 	GetUnderwaterLightmapSky(in vec2 coord) {
	return texture2D(composite, coord).r;
}


//Specularity
float 	GetSpecularity(in vec2 coord) {			//Function that retrieves how reflective any surface/pixel is in the scene. Used for reflections and specularity
	return texture2D(composite, texcoord.st).r;
}

float 	GetGlossiness(in vec2 coord) {			//Function that retrieves how reflective any surface/pixel is in the scene. Used for reflections and specularity
	return texture2D(composite, texcoord.st).g;
}



//Material IDs
float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

bool  	GetSky(in vec2 coord) {					//Function that returns true for any pixel that is part of the sky, and false for any pixel that isn't part of the sky
	float matID = GetMaterialIDs(coord);		//Gets texture that has all material IDs stored in it
		  matID = floor(matID * 255.0f);		//Scale texture from 0-1 float to 0-255 integer format
	
	if (matID == 0.0f) {						//Checks to see if the current pixel's material ID is 0 = the sky
		return true;							//If the current pixel has the material ID of 0 (sky material ID), Return "this pixel is part of the sky"
	} else {
		return false;							//Return "this pixel is not part of the sky"
	}
}

float 	GetMaterialMask(in vec2 coord ,const in int ID, in float matID) {
	matID = (matID * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
		return 1.0f;
	} else {
		return 0.0f;
	}
}




//Water
float 	GetWaterTex(in vec2 coord) {				//Function that returns the texture used for water. 0 means "this pixel is not water". 0.5 and greater means "this pixel is water".
	return texture2D(composite, coord).b;		//values from 0.5 to 1.0 represent the amount of sky light hitting the surface of the water. It is used to simulate fake sky reflections in composite1.fsh
}

float  	GetWaterMask(in vec2 coord, in float matID) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	matID = (matID * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return 1.0f;
	} else {
		return 0.0f;
	}
}




//Surface calculations
vec4  	GetScreenSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
		  depth += float(GetMaterialMask(coord, 5, GetMaterialIDs(coord))) * 0.38f;
		  //float handMask = float(GetMaterialMask(coord, 5, GetMaterialIDs(coord)));
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

		 //fragposition.xyz *= mix(1.0f, 15.0f, handMask);
	
	return fragposition;
}

vec4  	GetScreenSpacePosition(in vec2 coord, in float depth) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
		  //depth += float(GetMaterialMask(coord, 5)) * 0.38f;
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;
	
	return fragposition;
}

vec4 	GetWorldSpacePosition(in vec2 coord, in float depth)
{
	vec4 pos = GetScreenSpacePosition(coord, depth);
	pos = gbufferModelViewInverse * pos;
	pos.xyz += cameraPosition.xyz;

	return pos;
}

vec4 	GetCloudSpacePosition(in vec2 coord, in float depth, in float distanceMult)
{
	// depth *= 30.0f;

	float linDepth = depth;

	float expDepth = (far * (linDepth - near)) / (linDepth * (far - near));

	//Convert texture coordinates and depth into view space
	vec4 viewPos = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * expDepth - 1.0f, 1.0f);
		 viewPos /= viewPos.w;

	//Convert from view space to world space
	vec4 worldPos = gbufferModelViewInverse * viewPos;

	worldPos.xyz *= distanceMult;
	worldPos.xyz += cameraPosition.xyz;

	return worldPos;
}

vec4 	ScreenSpaceFromWorldSpace(in vec4 worldPosition)
{
	worldPosition.xyz -= cameraPosition;
	worldPosition = gbufferModelView * worldPosition;
	return worldPosition;
}



void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye
	
	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.4f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color
	
	color = mix(color, vec3(colorDesat) * rodColor, timeMidnight * amount);
	//color.rgb = color.rgb;	
}


float 	ExponentialToLinearDepth(in float depth)
{
	vec4 worldposition = vec4(depth);
	worldposition = gbufferProjection * worldposition;
	return worldposition.z;
}

float 	LinearToExponentialDepth(in float linDepth)
{
	float expDepth = (far * (linDepth - near)) / (linDepth * (far - near));
	return expDepth;
}

void 	DoLowlightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye
	
	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.4f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color
	
	color = mix(color, vec3(colorDesat) * rodColor, amount);
	// color.rgb = color.rgb;	
}

void 	FixLightFalloff(inout float lightmap) { //Fixes the ugly lightmap falloff and creates a nice linear one
	float additive = 5.35f;
	float exponent = 40.0f;

	lightmap += additive;							//Prevent ugly fast falloff
	lightmap = pow(lightmap, exponent);			//Curve light falloff
	lightmap = max(0.0f, lightmap);		//Make sure light properly falls off to zero
	lightmap /= pow(1.0f + additive, exponent);
}


float 	CalculateLuminance(in vec3 color) {
	return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

vec3 	Glowmap(in vec3 albedo, in float mask, in float curve, in vec3 emissiveColor) {
	vec3 color = albedo * (mask);
		 color = pow(color, vec3(curve));
		 color = vec3(CalculateLuminance(color));
		 color *= emissiveColor;

	return color;
}


float 	ChebyshevUpperBound(in vec2 moments, in float distance) {
	if (distance <= moments.x)
		return 1.0f;

	float variance = moments.y - (moments.x * moments.x);
		  variance = max(variance, 0.000002f);

	float d = distance - moments.x;
	float pMax = variance / (variance + d*d);

	return pMax;
}

float  	CalculateDitherPattern() {
	const int[4] ditherPattern = int[4] (0, 2, 1, 4);

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 2.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 2.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 2];

	return float(dither) / 4.0f;
}


float  	CalculateDitherPattern1() {
	const int[16] ditherPattern = int[16] (0 , 8 , 2 , 10,
									 	   12, 4 , 14, 6 ,
									 	   3 , 11, 1,  9 ,
									 	   15, 7 , 13, 5 );

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 16.0f;
}

float  	CalculateDitherPattern2() {
	const int[64] ditherPattern = int[64] ( 1, 49, 13, 61,  4, 52, 16, 64,
										   33, 17, 45, 29, 36, 20, 48, 32,
										    9, 57,  5, 53, 12, 60,  8, 56,
										   41, 25, 37, 21, 44, 28, 40, 24,
										    3, 51, 15, 63,  2, 50, 14, 62,
										   35, 19, 47, 31, 34, 18, 46, 30,
										   11, 59,  7, 55, 10, 58,  6, 54,
										   43, 27, 39, 23, 42, 26, 38, 22);

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 8.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 8.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 8];

	return float(dither) / 65.0f;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
}


void DrawDebugSquare(inout vec3 color) {

	vec2 pix = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	vec2 offset = vec2(0.5f);
	vec2 size = vec2(0.0f);
		 size.x = 1.0f / 2.0f;
		 size.y = 1.0f / 2.0f;

	vec2 padding = pix * 0.0f;
		 size += padding;

	if ( texcoord.s + offset.s / 2.0f + padding.x / 2.0f > offset.s &&
		 texcoord.s + offset.s / 2.0f + padding.x / 2.0f < offset.s + size.x &&
		 texcoord.t + offset.t / 2.0f + padding.y / 2.0f > offset.t &&
		 texcoord.t + offset.t / 2.0f + padding.y / 2.0f < offset.t + size.y
		)
	{
		
		int[16] ditherPattern = int[16] (0, 3, 0, 3,
										 2, 1, 2, 1,
										 0, 3, 0, 3,
										 2, 1, 2, 1);

		vec2 count = vec2(0.0f);
		     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
			 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

		int dither = ditherPattern[int(count.x) + int(count.y) * 4];
		color.rgb = vec3(float(dither) / 3.0f);
		
		
	}

}

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct MCLightmapStruct {		//Lightmaps directly from MC engine
	float torch;				//Light emitted from torches and other emissive blocks
	float sky;					//Light coming from the sky
	float lightning;			//Light coming from lightning

	vec3 torchVector; 			//Vector in screen space that represents the direction of average light transfered
	vec3 skyVector;
} mcLightmap;



struct DiffuseAttributesStruct {			//Diffuse surface shading attributes
	float roughness;			//Roughness of surface. More roughness will use Oren Nayar reflectance.
	float translucency; 		//How translucent the surface is. Translucency represents how much energy will be transfered through the surface
	vec3  translucencyColor; 	//Color that will be multiplied with sunlight for backsides of translucent materials.
};

struct SpecularAttributesStruct {			//Specular surface shading attributes
	float specularity;			//How reflective a surface is
	float extraSpecularity;		//Additional reflectance for specular reflections from sun only
	float glossiness;			//How smooth or rough a specular surface is
	float metallic;				//from 0 - 1. 0 representing non-metallic, 1 representing fully metallic.
	float gain;					//Adjust specularity further
	float base;					//Reflectance when the camera is facing directly at the surface normal. 0 allows only the fresnel effect to add specularity
	float fresnelPower; 		//Curve of fresnel effect. Higher values mean the surface has to be viewed at more extreme angles to see reflectance
};

struct SkyStruct { 				//All sky shading attributes
	vec3 	albedo;				//Diffuse texture aka "color texture" of the sky
	vec3 	tintColor; 			//Color that will be multiplied with the sky to tint it
	vec3 	sunglow;			//Color that will be added to the sky simulating scattered light arond the sun/moon
	vec3 	sunSpot; 			//Actual sun surface
};

struct WaterStruct {
	vec3 albedo;
};

struct MaskStruct {

	float matIDs;

	float sky;
	float land;
	float grass;
	float leaves;
	float ice;
	float hand;
	float translucent;
	float glow;
	float sunspot;
	float goldBlock;
	float ironBlock;
	float diamondBlock;
	float emeraldBlock;
	float sand;
	float sandstone;
	float stone;
	float cobblestone;
	float wool;
	float clouds;

	float torch;
	float lava;
	float glowstone;
	float fire;

	float water;

	float volumeCloud;

};

struct CloudsStruct {
	vec3 albedo;
};

struct AOStruct {
	float skylight;
	float scatteredUpLight;
	float bouncedSunlight;
	float scatteredSunlight;
	float constant;
};

struct Ray {
	vec3 dir;
	vec3 origin;
};

struct Plane {
	vec3 normal;
	vec3 origin;
};

struct SurfaceStruct { 			//Surface shading properties, attributes, and functions
	
	//Attributes that change how shading is applied to each pixel
		DiffuseAttributesStruct  diffuse;			//Contains all diffuse surface attributes
		SpecularAttributesStruct specular;			//Contains all specular surface attributes

	SkyStruct 	    sky;			//Sky shading attributes and properties
	WaterStruct 	water;			//Water shading attributes and properties
	MaskStruct 		mask;			//Material ID Masks
	CloudsStruct 	clouds;
	AOStruct 		ao;				//ambient occlusion
	
	//Properties that are required for lighting calculation
		vec3 	albedo;					//Diffuse texture aka "color texture"
		vec3 	normal;					//Screen-space surface normals
		float 	depth;					//Scene depth
		float   linearDepth; 			//Linear depth

		vec4	screenSpacePosition;	//Vector representing the screen-space position of the surface
		vec3 	viewVector; 			//Vector representing the viewing direction
		vec3 	lightVector; 			//Vector representing sunlight direction
		Ray 	viewRay;
		vec3 	worldLightVector;
		vec3  	upVector;				//Vector representing "up" direction
		float 	NdotL; 					//dot(normal, lightVector). used for direct lighting calculation
		vec3 	debug;

		float 	shadow;	
		float 	cloudShadow;

		float 	cloudAlpha;			
} surface;

struct LightmapStruct {			//Lighting information to light the scene. These are untextured colored lightmaps to be multiplied with albedo to get the final lit and textured image.
	vec3 sunlight;				//Direct light from the sun
	vec3 skylight;				//Ambient light from the sky
	vec3 bouncedSunlight;		//Fake bounced light, coming from opposite of sun direction and adding to ambient light
	vec3 scatteredSunlight;		//Fake scattered sunlight, coming from same direction as sun and adding to ambient light
	vec3 scatteredUpLight; 		//Fake GI from ground
	vec3 torchlight;			//Light emitted from torches and other emissive blocks
	vec3 lightning;				//Light caused by lightning
	vec3 nolight;				//Base ambient light added to everything. For lighting caves so that the player can barely see even when no lights are present
	vec3 specular;				//Reflected direct light from sun
	vec3 translucent;			//Light on the backside of objects representing thin translucent materials
	vec3 sky;					//Color and brightness of the sky itself
	vec3 underwater;			//underwater lightmap
	vec3 heldLight; 			
} lightmap;

struct ShadingStruct {			//Shading calculation variables
	float   direct;
	float 	waterDirect;
	float 	bounced; 			//Fake bounced sunlight
	float 	skylight; 			//Light coming from sky
	float 	scattered; 			//Fake scattered sunlight
	float   scatteredUp; 		//Fake GI from ground
	float 	specular; 			//Reflected direct light
	float 	translucent; 		//Backside of objects lit up from the sun via thin translucent materials	
	float 	sunlightVisibility; //Shadows
	float 	heldLight;
} shading;

struct GlowStruct {
	vec3 torch;
	vec3 lava;
	vec3 glowstone;
	vec3 fire;
};

struct FinalStruct {			//Final textured and lit images sorted by what is illuminating them.
	
	GlowStruct 		glow;		//Struct containing emissive material final images

	vec3 sunlight;				//Direct light from the sun
	vec3 skylight;				//Ambient light from the sky
	vec3 bouncedSunlight;		//Fake bounced light, coming from opposite of sun direction and adding to ambient light
	vec3 scatteredSunlight;		//Fake scattered sunlight, coming from same direction as sun and adding to ambient light
	vec3 scatteredUpLight; 		//Fake GI from ground
	vec3 torchlight;			//Light emitted from torches and other emissive blocks
	vec3 lightning;				//Light caused by lightning
	vec3 nolight;				//Base ambient light added to everything. For lighting caves so that the player can barely see even when no lights are present
	vec3 translucent;			//Light on the backside of objects representing thin translucent materials
	vec3 sky;					//Color and brightness of the sky itself
	vec3 underwater;			//underwater colors
	vec3 heldLight;
	

} final;

struct Intersection {
	vec3 pos;
	float distance;
	float angle;
};




/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Mask
void 	CalculateMasks(inout MaskStruct mask) {
		if (isEyeInWater > 0)
			mask.sky = 0.0f;
		else
			mask.sky 			= GetMaterialMask(texcoord.st, 0, mask.matIDs);

		mask.land	 		= GetMaterialMask(texcoord.st, 1, mask.matIDs);
		mask.grass 			= GetMaterialMask(texcoord.st, 2, mask.matIDs);
		mask.leaves	 		= GetMaterialMask(texcoord.st, 3, mask.matIDs);
		mask.ice		 	= GetMaterialMask(texcoord.st, 4, mask.matIDs);
		mask.hand	 		= GetMaterialMask(texcoord.st, 5, mask.matIDs);
		mask.translucent	= GetMaterialMask(texcoord.st, 6, mask.matIDs);

		mask.glow	 		= GetMaterialMask(texcoord.st, 10, mask.matIDs);
		mask.sunspot 		= GetMaterialMask(texcoord.st, 11, mask.matIDs);

		mask.goldBlock 		= GetMaterialMask(texcoord.st, 20, mask.matIDs);
		mask.ironBlock 		= GetMaterialMask(texcoord.st, 21, mask.matIDs);
		mask.diamondBlock	= GetMaterialMask(texcoord.st, 22, mask.matIDs);
		mask.emeraldBlock	= GetMaterialMask(texcoord.st, 23, mask.matIDs);
		mask.sand	 		= GetMaterialMask(texcoord.st, 24, mask.matIDs);
		mask.sandstone 		= GetMaterialMask(texcoord.st, 25, mask.matIDs);
		mask.stone	 		= GetMaterialMask(texcoord.st, 26, mask.matIDs);
		mask.cobblestone	= GetMaterialMask(texcoord.st, 27, mask.matIDs);
		mask.wool			= GetMaterialMask(texcoord.st, 28, mask.matIDs);
		mask.clouds 		= GetMaterialMask(texcoord.st, 29, mask.matIDs);

		mask.torch 			= GetMaterialMask(texcoord.st, 30, mask.matIDs);
		mask.lava 			= GetMaterialMask(texcoord.st, 31, mask.matIDs);
		mask.glowstone 		= GetMaterialMask(texcoord.st, 32, mask.matIDs);
		mask.fire 			= GetMaterialMask(texcoord.st, 33, mask.matIDs);

		mask.water 			= GetWaterMask(texcoord.st, mask.matIDs);

		mask.volumeCloud 	= 0.0f;
}

//Surface
void 	CalculateNdotL(inout SurfaceStruct surface) {		//Calculates direct sunlight without visibility check
	float direct = dot(surface.normal.rgb, surface.lightVector);
		  direct = direct * 1.0f + 0.0f;
		  //direct = clamp(direct, 0.0f, 1.0f);

	surface.NdotL = direct;
}

float 	CalculateDirectLighting(in SurfaceStruct surface) {

	//Tall grass translucent shading
	if (surface.mask.grass > 0.5f) {
		return 1.0f;
	

	//Leaves
	} else if (surface.mask.leaves > 0.5f) {

		// if (surface.NdotL > -0.01f) {
		// 	return surface.NdotL * 0.99f + 0.01f;
		// } else {
		// 	return abs(surface.NdotL) * 0.25f;
		// }

		return 1.0f;


	//clouds
	} else if (surface.mask.clouds > 0.5f) {

		return 0.5f;


	} else if (surface.mask.ice > 0.5f) {

		return pow(surface.NdotL * 0.5 + 0.5, 2.0f);

	//Default lambert shading
	} else {
		return max(0.0f, surface.NdotL * 0.99f + 0.01f);
	}
}

float 	CalculateSunlightVisibility(inout SurfaceStruct surface, in ShadingStruct shadingStruct) {				//Calculates shadows
	if (rainStrength >= 0.99f)
		return 1.0f;


	if (shadingStruct.direct > 0.0f) {
		float distance = sqrt(  surface.screenSpacePosition.x * surface.screenSpacePosition.x 	//Get surface distance in meters
							  + surface.screenSpacePosition.y * surface.screenSpacePosition.y 
							  + surface.screenSpacePosition.z * surface.screenSpacePosition.z);
		
		vec4 worldposition = vec4(0.0f);
			 worldposition = gbufferModelViewInverse * surface.screenSpacePosition;		//Transform from screen space to world space
			
		float yDistanceSquared  = worldposition.y * worldposition.y;
		
		worldposition = shadowModelView * worldposition;	//Transform from world space to shadow space
		float comparedepth = -worldposition.z;				//Surface distance from sun to be compared to the shadow map
		
		worldposition = shadowProjection * worldposition;													
		worldposition /= worldposition.w;

		float dist = sqrt(worldposition.x * worldposition.x + worldposition.y * worldposition.y);
		float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
		worldposition.xy *= 1.0f / distortFactor;
		worldposition = worldposition * 0.5f + 0.5f;		//Transform from shadow space to shadow map coordinates
		
		float shadowMult = 0.0f;																			//Multiplier used to fade out shadows at distance
		float shading = 0.0f;
		
		if (distance < shadowDistance && comparedepth > 0.0f &&											//Avoid computing shadows past the shadow map projection
			 worldposition.s < 1.0f && worldposition.s > 0.0f && worldposition.t < 1.0f && worldposition.t > 0.0f) {
			 
			float fademult = 0.15f;
				shadowMult = clamp((shadowDistance * 0.85f * fademult) - (distance * fademult), 0.0f, 1.0f);	//Calculate shadowMult to fade shadows out
			
			float diffthresh = dist * 1.0f + 0.10f;
				  diffthresh *= 3.0f / (shadowMapResolution / 2048.0f);
				  //diffthresh /= shadingStruct.direct + 0.1f;

			#if defined ENABLE_SOFT_SHADOWS

				int count = 0;
				float spread = 0.8f / shadowMapResolution;

				for (float i = -3.0f; i <= 3.0f; i += 1.0f) {
					for (float j = -3.0f; j <= 3.0f; j += 1.0f) {
						 shading += shadow2D(shadow, vec3(worldposition.st + vec2(i, j) * spread, worldposition.z - 0.0018f * diffthresh)).x;
						count += 1;
					}
				}
				shading /= count;
				 	
			#else
				//diffthresh *= 2.0f;
				shading = shadow2DLod(shadow, vec3(worldposition.st, worldposition.z - 0.0006f * diffthresh), 0).x;
			#endif

			
		}
		
		shading = mix(1.0f, shading, shadowMult);

		surface.shadow = shading;
		
		return shading;
	} else {
		return 0.0f;
	}
}

float 	CalculateBouncedSunlight(in SurfaceStruct surface) {

	float NdotL = surface.NdotL;
	float bounced = clamp(-NdotL + 0.95f, 0.0f, 1.95f) / 1.95f;
		  bounced = bounced * bounced * bounced;
	
	return bounced;
}

float 	CalculateScatteredSunlight(in SurfaceStruct surface) {

	float NdotL = surface.NdotL;
	float scattered = clamp(NdotL * 0.75f + 0.25f, 0.0f, 1.0f);
		  //scattered *= scattered * scattered;
		  
	return scattered;
}

float 	CalculateSkylight(in SurfaceStruct surface) {

	if (surface.mask.clouds > 0.5f) {
		return 1.0f;

	// } else if (surface.mask.leaves) {

	// 	return 1.0f;

	} else if (surface.mask.grass > 0.5f) {

		return 1.0f;

	} else {

		float skylight = dot(surface.normal, surface.upVector);
			  skylight = skylight * 0.45f + 0.55f;

		return skylight;
	}
}

float 	CalculateScatteredUpLight(in SurfaceStruct surface) {
	float scattered = dot(surface.normal, surface.upVector);
		  scattered = scattered * 0.5f + 0.5f;
		  scattered = 1.0f - scattered;

	return scattered;
}

float CalculateHeldLightShading(in SurfaceStruct surface)
{
	vec3 lightPos = vec3(0.0f);
	vec3 lightVector = normalize(lightPos - surface.screenSpacePosition.xyz);
	float lightDist = length(lightPos.xyz - surface.screenSpacePosition.xyz);

	float atten = 1.0f / (pow(lightDist, 2.0f) + 0.001f);
	float NdotL = 1.0f;

	return atten * NdotL;
}

float   CalculateSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return pow(factor,3.0);
}

float   CalculateAntiSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

bool   CalculateSunspot(in SurfaceStruct surface) {

	//circular sun
	float curve = 1.0f;

	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);

	float sunProximity = 1.0f - dot(halfVector2, npos);

	if (sunProximity > 0.96f && sunAngle > 0.0f && sunAngle < 0.5f) {
		return true;
	} else {
		return false;
	}

	//Sun based on matID

	// if (surface.mask.sunspot)
	// 	return true;
	// else
	// 	return false;
}

void 	GetLightVectors(inout MCLightmapStruct mcLightmap, in SurfaceStruct surface) {

	vec2 torchDiff = vec2(0.0f);
		 torchDiff.x = GetLightmapTorch(texcoord.st) - GetLightmapTorch(texcoord.st + vec2(1.0f / viewWidth, 0.0f));
		 torchDiff.y = GetLightmapTorch(texcoord.st) - GetLightmapTorch(texcoord.st + vec2(0.0f, 1.0f / viewWidth));

		 //torchDiff /= GetDepthLinear(texcoord.st);

	mcLightmap.torchVector.x = torchDiff.x * 200.0f;
	//mcLightmap.torchVector.x *= 1.0f - surface.viewVector.x;

	mcLightmap.torchVector.y = torchDiff.y * 200.0f;

	mcLightmap.torchVector.x = 1.0f;
	mcLightmap.torchVector.y = 0.0f;
	mcLightmap.torchVector.z = sqrt(1.0f - mcLightmap.torchVector.x * mcLightmap.torchVector.x + mcLightmap.torchVector.y + mcLightmap.torchVector.y);

	


	float torchNormal = dot(surface.normal.rgb, mcLightmap.torchVector.rgb);

	mcLightmap.torchVector.x = torchNormal;


	//mcLightmap.torchVector = mcLightmap.torchVector * 0.5f + 0.5f;
}

void 	AddSkyGradient(inout SurfaceStruct surface) {
	float curve = 5.0f;
	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.upVector + npos);
	float skyGradientFactor = dot(halfVector2, npos);
	float skyDirectionGradient = skyGradientFactor;

	if (dot(halfVector2, npos) > 0.75)
		skyGradientFactor = 1.5f - skyGradientFactor;

	skyGradientFactor = pow(skyGradientFactor, curve);

	surface.sky.albedo = CalculateLuminance(surface.sky.albedo) * colorSkylight;

	surface.sky.albedo *= mix(skyGradientFactor, 1.0f, clamp((0.12f - (timeNoon * 0.1f)) + rainStrength, 0.0f, 1.0f));
	surface.sky.albedo *= pow(skyGradientFactor, 2.5f) + 0.2f;
	surface.sky.albedo *= (pow(skyGradientFactor, 1.1f) + 0.425f) * 0.5f;
	surface.sky.albedo.g *= skyGradientFactor * 1.0f + 1.0f;


	vec3 linFogColor = pow(gl_Fog.color.rgb, vec3(2.2f));

	float fogLum = max(max(linFogColor.r, linFogColor.g), linFogColor.b);


	float fade1 = clamp(skyGradientFactor - 0.05f, 0.0f, 0.2f) / 0.2f;
		  fade1 = fade1 * fade1 * (3.0f - 2.0f * fade1);
	vec3 color1 = vec3(12.0f, 8.0, 4.7f) * 0.15f;
		 color1 = mix(color1, vec3(2.0f, 0.55f, 0.2f), vec3(timeSunriseSunset));

	surface.sky.albedo *= mix(vec3(1.0f), color1, vec3(fade1));

	float fade2 = clamp(skyGradientFactor - 0.11f, 0.0f, 0.2f) / 0.2f;
	vec3 color2 = vec3(2.7f, 1.0f, 2.8f) / 20.0f;
		 color2 = mix(color2, vec3(1.0f, 0.15f, 0.5f), vec3(timeSunriseSunset));

	surface.sky.albedo *= mix(vec3(1.0f), color2, vec3(fade2 * 0.5f));



	float horizonGradient = 1.0f - distance(skyDirectionGradient, 0.72f) / 0.72f;
		  horizonGradient = pow(horizonGradient, 10.0f);
		  horizonGradient = max(0.0f, horizonGradient);

	float sunglow = CalculateSunglow(surface);
		  horizonGradient *= sunglow * 2.0f + (0.65f - timeSunriseSunset * 0.55f);

	vec3 horizonColor1 = vec3(1.5f, 1.5f, 1.5f);
		 horizonColor1 = mix(horizonColor1, vec3(1.5f, 1.95f, 1.5f) * 2.0f, vec3(timeSunriseSunset));
	vec3 horizonColor2 = vec3(1.5f, 1.2f, 0.8f) * 1.0f;
		 horizonColor2 = mix(horizonColor2, vec3(1.9f, 0.6f, 0.4f) * 2.0f, vec3(timeSunriseSunset));

	surface.sky.albedo *= mix(vec3(1.0f), horizonColor1, vec3(horizonGradient) * (1.0f - timeMidnight));
	surface.sky.albedo *= mix(vec3(1.0f), horizonColor2, vec3(pow(horizonGradient, 2.0f)) * (1.0f - timeMidnight));

	float grayscale = fogLum / 10.0f;
		  grayscale /= 3.0f;

	surface.sky.albedo = mix(surface.sky.albedo, vec3(grayscale * colorSkylight.r) * 0.06f * vec3(0.85f, 0.85f, 1.0f), vec3(rainStrength));


	surface.sky.albedo /= fogLum;


	surface.sky.albedo *= mix(1.0f, 4.5f, timeNoon);
	


	// //Fake land
	// vec3 fakeLandColor = vec3(0.2f, 0.5f, 1.0f) * 0.006f;
	// surface.sky.albedo = mix(surface.sky.albedo, fakeLandColor, vec3(clamp(skyGradientFactor * 8.0f - 0.7f, 0.0f, 1.0f)));


	surface.sky.albedo *= (surface.mask.sky);
}

void 	AddSunglow(inout SurfaceStruct surface) {
	float sunglowFactor = CalculateSunglow(surface);
	float antiSunglowFactor = CalculateAntiSunglow(surface);

	surface.sky.albedo *= 1.0f + pow(sunglowFactor, 1.1f) * (5.0f + timeNoon * 1.0f) * (1.0f - rainStrength);
	surface.sky.albedo *= mix(vec3(1.0f), colorSunlight * 6.0f, pow(clamp(vec3(sunglowFactor) * (1.0f - timeMidnight) * (1.0f - rainStrength), vec3(0.0f), vec3(1.0f)), vec3(2.0f)));

	surface.sky.albedo *= 1.0f + antiSunglowFactor * 2.0f * (1.0f - rainStrength);
	//surface.sky.albedo *= mix(vec3(1.0f), colorSunlight, antiSunglowFactor);
}


void 	AddCloudGlow(inout vec3 color, in SurfaceStruct surface) {
	float glow = CalculateSunglow(surface);
		  glow = pow(glow, 1.0f);

	float mult = mix(50.0f, 800.0f, timeSkyDark);

	color.rgb *= 1.0f + glow * mult * (surface.mask.clouds);
}


void 	CalculateUnderwaterFog(in SurfaceStruct surface, inout vec3 finalComposite) {
	vec3 fogColor = colorWaterMurk * vec3(colorSkylight.b);
	// float fogDensity = 0.045f;
	// float fogFactor = exp(GetDepthLinear(texcoord.st) * fogDensity) - 1.0f;
	// 	  fogFactor = min(fogFactor, 1.0f);
	float fogFactor = GetDepthLinear(texcoord.st) / 100.0f;
		  fogFactor = min(fogFactor, 0.7f);
		  fogFactor = sin(fogFactor * 3.1415 / 2.0f);
		  fogFactor = pow(fogFactor, 0.5f);

	
	finalComposite.rgb = mix(finalComposite.rgb, fogColor * 0.002f, vec3(fogFactor));
	finalComposite.rgb *= mix(vec3(1.0f), colorWaterBlue * colorWaterBlue * colorWaterBlue * colorWaterBlue, vec3(fogFactor));
	//finalComposite.rgb = vec3(0.1f);
}

void 	TestRaymarch(inout vec3 color, in SurfaceStruct surface)
{

	//visualize march steps
	float rayDepth = 0.0f;
	float rayIncrement = 0.05f;
	float fogFactor = 0.0f;

	while (rayDepth < 1.0f)
	{
		vec4 rayPosition = GetScreenSpacePosition(texcoord.st, pow(rayDepth, 0.002f));



		if (abs(rayPosition.z - surface.screenSpacePosition.z) < 0.025f)
		{
			color.rgb = vec3(0.01f, 0.0f, 0.0f);
		}

		// if (SphereTestDistance(vec3(surface.screenSpacePosition.x, surface.screenSpacePosition.y, surface.screenSpacePosition.z)) <= 0.001f)
		// 	fogFactor += 0.001f;

		rayDepth += rayIncrement;

	}

	// color.rgb = mix(color.rgb, vec3(1.0f) * 0.01f, fogFactor);

	// vec4 newPosition = surface.screenSpacePosition;

	// color.rgb = vec3(distance(newPosition.rgb, vec3(0.0f, 0.0f, 0.0f)) * 0.00001f);

}

void InitializeAO(inout SurfaceStruct surface)
{
	surface.ao.skylight = 1.0f;
	surface.ao.bouncedSunlight = 1.0f;
	surface.ao.scatteredUpLight = 1.0f;
	surface.ao.constant = 1.0f;
}

void CalculateAO(inout SurfaceStruct surface)
{
	const int numSamples = 20;
	vec3[numSamples] kernel;

	vec3 stochastic = texture2D(noisetex, texcoord.st * vec2(viewWidth, viewHeight) / noiseTextureResolution).rgb;

	//Generate positions for sample points in hemisphere
	for (int i = 0; i < numSamples; i++)
	{
		//Random direction
		kernel[i] = vec3(texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).r * 2.0f - 1.0f, 
					     texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).g * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).b * 2.0f - 1.0f);
		//kernel[i] += (stochastic * vec3(2.0f, 2.0f, 1.0f) - vec3(1.0f, 1.0f, 0.0f)) * 0.0f;
		kernel[i] = normalize(kernel[i]);

		//scale randomly to distribute within hemisphere;
		kernel[i] *= pow(texture2D(noisetex, vec2(0.3f + (i * 1.0f) / noiseTextureResolution)).r * CalculateNoisePattern1(vec2(43.0f), 64.0f).x * 1.0f, 1.2f);
	}

	//Determine origin position and normal
	vec3 origin = surface.screenSpacePosition.xyz;
	vec3 normal = surface.normal.xyz;
		 //normal = lightVector;

	//Create matrix to orient hemisphere according to surface normal
	//vec3 randomRotation = texture2D(noisetex, texcoord.st * vec2(viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).rgb * 2.0f - 1.0f;
		//float dither1 = CalculateDitherPattern1() * 2.0f - 1.0f;
		//randomRotation = vec3(dither1, mod(dither1 + 0.5f, 2.0f), mod(dither1 + 1.0f, 2.0f));
	vec3	randomRotation = CalculateNoisePattern1(vec2(0.0f), 64.0f).xyz * 2.0f - 1.0f;
	//vec3	randomRotation = vec3(1.0f, 0.0f, 0.0f);


	vec3 tangent = normalize(randomRotation - upVector * dot(randomRotation, upVector));
	vec3 bitangent = cross(upVector, tangent);
	mat3 tbn = mat3(tangent, bitangent, upVector);

	float ao = 0.0f;
	float aoSkylight	= 0.0f;
	float aoUp  		= 0.0f;
	float aoBounced  	= 0.0f;
	float aoScattered  	= 0.0f;


	float aoRadius   = 0.35f * -surface.screenSpacePosition.z;
		  //aoRadius   = 3.0f;
	float zThickness = 0.35f * -surface.screenSpacePosition.z;
		  zThickness = 6.0f;


	vec3 	samplePosition 		= vec3(0.0f);
	float 	intersect 			= 0.0f;
	vec4 	sampleScreenSpace 	= vec4(0.0f);
	float 	sampleDepth 		= 0.0f;
	float 	distanceWeight 		= 0.0f;
	float 	finalRadius 		= 0.0f;

	float skylightWeight = 0.0f;
	float bouncedWeight  = 0.0f;
	float scatteredUpWeight = 0.0f;
	float scatteredSunWeight = 0.0f;
	vec3 bentNormal = vec3(0.0f);

	for (int i = 0; i < numSamples; i++)
	{
		samplePosition = tbn * kernel[i];
		samplePosition = samplePosition * aoRadius + origin;

		intersect = dot(normalize(samplePosition - origin), surface.normal);

		if (intersect > 0.2f) {
			//Convert camera space to screen space
			sampleScreenSpace = gbufferProjection * vec4(samplePosition, 1.0f);
			sampleScreenSpace.xyz /= sampleScreenSpace.w;
			sampleScreenSpace.xyz = sampleScreenSpace.xyz * 0.5f + 0.5f;

			//Check depth at sample point
			sampleDepth = GetScreenSpacePosition(sampleScreenSpace.xy).z;

			//If point is behind geometry, buildup AO
			if (sampleDepth >= samplePosition.z && surface.mask.sky < 0.5f)
			{	
				//Reduce halo
				float sampleLength = length(samplePosition - origin) * 4.0f;
				//distanceWeight = 1.0f - clamp(distance(sampleDepth, origin.z) - (sampleLength * 0.5f), 0.0f, sampleLength * 0.5f) / (sampleLength * 0.5f);
				distanceWeight = 1.0f - step(sampleLength, distance(sampleDepth, origin.z));

				//Weigh samples based on light direction
				skylightWeight 			= clamp(dot(normalize(samplePosition - origin), upVector)		* 1.0f - 0.0f , 0.0f, 0.01f) / 0.01f;
				//skylightWeight 		   += clamp(dot(normalize(samplePosition - origin), upVector), 0.0f, 1.0f);
				bouncedWeight 			= clamp(dot(normalize(samplePosition - origin), -lightVector)	* 1.0f - 0.0f , 0.0f, 0.51f) / 0.51f;
				scatteredUpWeight 		= clamp(dot(normalize(samplePosition - origin), -upVector)	 	* 1.0f - 0.0f , 0.0f, 0.51f) / 0.51f;
				scatteredSunWeight 		= clamp(dot(normalize(samplePosition - origin), lightVector)	* 1.0f - 0.25f, 0.0f, 0.51f) / 0.51f;
					  
					  //buildup occlusion more for further facing surfaces
				 	  skylightWeight 			/= clamp(dot(normal, upVector) 			* 0.5f + 0.501f, 0.01f, 1.0f);
				 	  bouncedWeight 			/= clamp(dot(normal, -lightVector) 		* 0.5f + 0.501f, 0.01f, 1.0f);
				 	  scatteredUpWeight 		/= clamp(dot(normal, -upVector) 		* 0.5f + 0.501f, 0.01f, 1.0f);
				 	  scatteredSunWeight 		/= clamp(dot(normal, lightVector) 		* 0.75f + 0.25f, 0.01f, 1.0f);


				//Accumulate ao
				ao 			+= 2.0f * distanceWeight;
				aoSkylight  += 2.0f * distanceWeight * skylightWeight		;
				aoUp 		+= 2.0f * distanceWeight * scatteredUpWeight	;
				aoBounced 	+= 2.0f * distanceWeight * bouncedWeight		;
				aoScattered += 2.0f * distanceWeight * scatteredSunWeight   ;
			} else {
				bentNormal.rgb += normalize(samplePosition - origin);
			}
		}
	}

	bentNormal.rgb /= numSamples;

	ao 			/= numSamples;
	aoSkylight  /= numSamples;
	aoUp 		/= numSamples;
	aoBounced 	/= numSamples;
	aoScattered /= numSamples;

	ao 			= 1.0f - ao;
	aoSkylight 	= 1.0f - aoSkylight;
	aoUp 		= 1.0f - aoUp;
	aoBounced   = 1.0f - aoBounced;
	aoScattered = 1.0f - aoScattered;

	ao 			= clamp(ao, 			0.0f, 1.0f);
	aoSkylight 	= clamp(aoSkylight, 	0.0f, 1.0f);
	aoUp 		= clamp(aoUp, 			0.0f, 1.0f);
	aoBounced 	= clamp(aoBounced,		0.0f, 1.0f);
	aoScattered = clamp(aoScattered, 	0.0f, 1.0f);

	surface.ao.constant 				= pow(ao, 			1.0f);
	surface.ao.skylight 				= pow(aoSkylight, 	3.0f);
	surface.ao.bouncedSunlight 			= pow(aoBounced, 	6.0f);
	surface.ao.scatteredUpLight 		= pow(aoUp, 		6.0f);
	surface.ao.scatteredSunlight 		= pow(aoScattered,  1.0f);

	surface.debug = vec3(pow(aoSkylight, 2.0f) * clamp((dot(surface.normal, upVector) * 0.75f + 0.25f), 0.0f, 1.0f));
	//surface.debug = vec3(dot(normalize(bentNormal), upVector));
}


void 	CalculateRainFog(inout vec3 color, in SurfaceStruct surface)
{
	vec3 fogColor = colorSkylight * 0.055f;

	float fogDensity = 0.00018f * rainStrength;
		  fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));
	float visibility = 1.0f / (pow(exp(distance(surface.screenSpacePosition.xyz, vec3(0.0f)) * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
		  fogFactor = clamp(fogFactor, 0.0f, 1.0f);
		  fogFactor = mix(fogFactor, 1.0f, (surface.mask.sky) * 0.8f * rainStrength);
		  fogFactor = mix(fogFactor, 1.0f, (surface.mask.clouds) * 0.8f * rainStrength);
		  fogFactor *= mix(1.0f, 0.0f, (surface.mask.sky));

	color = mix(color, fogColor, vec3(fogFactor));
}

void AtmosphericScattering(inout vec3 color, in SurfaceStruct surface)
{
	vec3 fogColor = colorSkylight * 0.2f;

	float sat = 0.5f;
		 fogColor.r = fogColor.r * (0.0f + sat) - (fogColor.g + fogColor.b) * 0.0f * sat;
		 fogColor.g = fogColor.g * (0.0f + sat) - (fogColor.r + fogColor.b) * 0.0f * sat;
		 fogColor.b = fogColor.b * (0.0f + sat) - (fogColor.r + fogColor.g) * 0.0f * sat;

	float sunglow = CalculateSunglow(surface);
	vec3 sunColor = colorSunlight;

	fogColor += mix(vec3(0.0f), sunColor, sunglow * 0.8f);

	float morning_fog_density = 0.021;
	float noon_fog_density    = 0.005;
	float sunset_fog_density  = 0.009;
	float evening_fog_density = 0.020;

	float fogDensity = morning_fog_density * timeSunrise + noon_fog_density * timeNoon + sunset_fog_density * timeSunset + sunset_fog_density * timeMidnight;

	float visibility = 1.25f / (pow(exp(surface.linearDepth * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
		  fogFactor = clamp(fogFactor, 0.0f, 1.0f);

	fogFactor = pow(fogFactor, 2.7f);
	fogFactor = mix(fogFactor, 0.0f, min(1.0f, surface.sky.sunSpot.r));
	fogFactor *= mix(1.0f, 0.25f, float(surface.mask.sky));
	fogFactor *= mix(1.0f, 0.75f, float(surface.mask.clouds));
	
	fogFactor *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 3.0f));

	float redshift = 1.0f;

	//scatter away high frequency light
	color.b *= 1.0f - clamp(fogFactor * 1.65 * redshift, 0.0f, 0.75f);
	color.g *= 1.0f - fogFactor * 0.2* redshift;
	color.g *= 1.0f - clamp(fogFactor - 0.26f, 0.0f, 1.0f) * 0.5* redshift;

	//add scattered low frequency light
	color += fogColor * fogFactor * 1.0f;

}

Intersection 	RayPlaneIntersectionWorld(in Ray ray, in Plane plane)
{
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f)
	{
		planeRayDist = dot((plane.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.dir * planeRayDist;
		intersectionPos = -intersectionPos;

		intersectionPos += cameraPosition.xyz;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}

Intersection 	RayPlaneIntersection(in Ray ray, in Plane plane)
{
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f)
	{
		planeRayDist = dot((plane.origin - ray.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.origin + ray.dir * planeRayDist;
		// intersectionPos = -intersectionPos;

		// intersectionPos += cameraPosition.xyz;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}

float CubicSmooth(float x)
{
	return x * x * (3.0 - 2.0 * x);
}

float Get3DNoise(in vec3 pos)
{
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	//f = f * f * (3.0f - 2.0f * f);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}

float Get3DNoise3(in vec3 pos)
{
	pos.z += 0.0f;

	pos.xyz += 0.5f;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	 f.x = f.x * f.x * (3.0f - 2.0f * f.x);
	 f.y = f.y * f.y * (3.0f - 2.0f * f.y);
	 f.z = f.z * f.z * (3.0f - 2.0f * f.z);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;

	 uv -= 0.5f;
	 uv2 -= 0.5f;

	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}

float GetCoverage(in float coverage, in float density, in float clouds)
{
        clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
                clouds = max(0.0f, clouds * 1.1f - 0.1f);
         // clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);
         // clouds = pow(clouds, 1.0f);
        return clouds;
}

float GetCoverage2(in float coverage, in float density, in float clouds)
{
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
		clouds = max(0.0f, clouds * 1.1f - 0.1f);
	 clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);
	 
	return clouds;
}

vec4 CloudColor3(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector)
{
	float cloudHeight = 200.0f;

	float cloudDepth  = 150.0f;

	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
		return vec4(0.0f);
	else
	{

		vec3 p = worldPosition.xyz / 150.0f;

		float t = frameTimeCounter * 2.0f ;
			 
		p.x -= t * 0.02f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 			   Get3DNoise(p) 				 * 1.0f;	p *= 4.0f;	p.x += t * 0.02f; vec3 p2 = p;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;	p *= 3.0f;	p.xz += t * 0.05f;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.5f)-0.2) * 0.065f;	p.xz -=t * 0.165f;	p.xz += t * 0.05f;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;	p *= 2.0f;
			  noise += (1.0 - abs(Get3DNoise3(p) * 2.0 - 1.0)) * 0.015f;
			  noise /= 1.2f;

		const float lightOffset = 0.3f;

		float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0f)), 0.0f, 1.0f);
		float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 150.0f)) / (cloudDepth * 1.0f)), 0.0f, 1.0f);

		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
			  cloudAltitudeWeight = (-cos(cloudAltitudeWeight * 3.1415f)) * 0.5 + 0.5;
			  cloudAltitudeWeight = pow(cloudAltitudeWeight, mix(0.33f, 0.8f, rainStrength));

		float cloudAltitudeWeight2 = 1.0f - clamp(distance(worldPosition.y + worldLightVector.y * lightOffset * 150.0f, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
			  cloudAltitudeWeight2 = (-cos(cloudAltitudeWeight2 * 3.1415f)) * 0.5 + 0.5;
			  cloudAltitudeWeight2 = pow(cloudAltitudeWeight2, mix(0.33f, 0.8f, rainStrength));

		noise *= cloudAltitudeWeight;


	
	//cloud edge
		float rainy = mix(wetness, 1.0f, rainStrength);
		float coverage = 0.48f + rainy * 0.335;
				

		coverage = mix(coverage, 0.77f, rainStrength);

		float dist = length(worldPosition.xz - cameraPosition.xz);
		coverage *= max(0.0f, 1.0f - dist / 40000.0f); 
		
		float density = 0.90f;
		noise = GetCoverage2(coverage, density, noise);
		noise = pow(noise, 1.5);
		
		if (noise <= 0.001f)
		{
			return vec4(0.0f, 0.0f, 0.0f, 0.0f);
		}

	float sundiff = Get3DNoise3(p1 + worldLightVector.xyz * lightOffset);
		  sundiff += (1.0 - abs(Get3DNoise3(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 1.0f - 0.5f) - 0.1) * 0.55f;
		  sundiff *= 0.955f;
		  sundiff *= cloudAltitudeWeight2;
	float preCoverage = sundiff;
		  sundiff = -GetCoverage2(coverage * 1.0f, density * 0.5, sundiff);
	
	float sundiff2 = -GetCoverage2(coverage * 1.0f, 0.0, preCoverage);
	float firstOrder 	= pow(clamp(sundiff * 1.2f + 1.7f, 0.0f, 1.0f), 8.0f);
	float secondOrder 	= pow(clamp(sundiff2 * 1.2f + 1.1f, 0.0f, 1.0f), 4.0f);

	float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));
		  firstOrder *= anisoBackFactor * 0.99 + 0.01;
		  secondOrder *= anisoBackFactor * 1.19 + 0.9;

	float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);
		  directLightFalloff *= mix(	clamp(pow(noise, 0.9f), 0.0f, 1.0f), 	clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f), 	pow(sunglow, 0.2f));

	vec3 colorDirect = colorSunlight * 12.5f;
		 colorDirect = mix(colorDirect, colorDirect * vec3(0.1f, 0.2f, 0.3f), timeMidnight);
		 colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), rainStrength);
		 colorDirect *= 1.0f + pow(sunglow, 4.0f) * 100.0f;

	vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
		 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);

	 vec3 colorBounced = colorBouncedSunlight * 0.35f;
	 	  colorBounced *= pow((1.0f - heightGradient), 8.0f);
	 	  colorBounced *= anisoBackFactor + 0.5;
	 	  colorBounced *= 1.0 - rainStrength;

		vec3 color = mix(colorAmbient, colorDirect, vec3(directLightFalloff));
			 color += colorBounced;

		color *= 1.0f;

		vec4 result = vec4(color.rgb, noise);

		return result;
	}
}

vec4 CloudColors(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector)
{

	float cloudHeight = 400.0f;
	float cloudDepth  = 150.0f;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
		return vec4(0.0f);
	else
	{

		vec3 p = worldPosition.xyz / 150.0f;



		float t = frameTimeCounter / 2.7f;
		p.x -= t * 0.02f;

		 p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.097f;	vec3 p2 = p;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;				p *= 3.0f;	p.xz -= t * 0.05f;	vec3 p3 = p;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.075f;				p *= 2.0f;	p.xz -= t * 0.05f;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;				p *= 2.0f;
			  noise /= 1.2f;



		const float lightOffset = 0.33f;


		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
			  cloudAltitudeWeight = pow(cloudAltitudeWeight, 0.5f);

		noise *= cloudAltitudeWeight;

		//cloud edge
		float rainy = mix(wetness, 1.0f, rainStrength);
		float coverage = 0.45f + rainy * 0.335f;
			  coverage = mix(coverage, 0.77f, rainStrength);
		float density = 0.66f;
		noise = clamp(noise - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);



		float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);

			  directLightFalloff *= mix(	clamp(pow(noise, 0.9f), 0.0f, 1.0f), 	clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f), 	pow(sunglow, 0.2f));

		vec3 colorDirect = colorSunlight * 25.0f;
		colorDirect = mix(colorDirect, colorDirect * vec3(0.1f, 0.2f, 0.3f), timeMidnight);
		colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), rainStrength);
		colorDirect *= 1.0f + pow(sunglow, 4.0f) * 100.0f;


		vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
			 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);


		vec3 color = mix(colorAmbient, colorDirect, vec3(directLightFalloff));

		vec4 result = vec4(color.rgb, noise);

		return result;
	}
}

vec4 CloudColorss(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector)
{

	float cloudHeight = 230.0f;
	float cloudDepth  = 150.0f;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
		return vec4(0.0f);
	else
	{

		vec3 p = worldPosition.xyz / 90.0f;

			

		float t = frameTimeCounter / 2.0f;
			  //t *= 0.001;
		p.x -= t * 0.02f;

		 p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 4.0f;	p.x -= t * 0.02f;	vec3 p2 = p;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;				p *= 3.0f;	p.xz -= t * 0.05f;	vec3 p3 = p;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.075f;				p *= 2.0f;	p.xz -= t * 0.05f;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;				p *= 2.0f;
			  noise /= 1.2f;



		const float lightOffset = 0.35f;


		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
			  cloudAltitudeWeight = pow(cloudAltitudeWeight, 0.5f);

		noise *= cloudAltitudeWeight;

		//cloud edge
		float coverage = 0.45f;
			  coverage = mix(coverage, 0.77f, rainStrength);
		float density = 0.66f;
		noise = clamp(noise - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);



		float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);

			  directLightFalloff *= mix(	clamp(pow(noise, 0.9f), 0.0f, 1.0f), 	clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f), 	pow(sunglow, 0.2f));

		vec3 colorDirect = colorSunlight * 38.0f;
		colorDirect = mix(colorDirect, colorDirect * vec3(0.1f, 0.2f, 0.3f), timeMidnight);
		colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), rainStrength);
		colorDirect *= 1.0f + pow(sunglow, 4.0f) * 100.0f;


		vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
			 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);


		vec3 color = mix(colorAmbient, colorDirect, vec3(directLightFalloff));

		vec4 result = vec4(color.rgb, noise);

		return result;
	}
}

vec4 CloudColorsss(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector)
{

	float cloudHeight = 600.0f;
	float cloudDepth  = 100.0f;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
		return vec4(0.0f);
	else
	{

		vec3 p = worldPosition.xyz / 200.0f;
		float t = frameTimeCounter;
			  //t *= 100.0;
		p.x += t * 0.02f;
		float noise  = 			   Get3DNoise(p) 				 * 1.0f;	p *= 4.0f;	p.x += t * 0.02f;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;	p *= 2.0f;	p.xz += t * 0.05f;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.075f;	p *= 2.0f;	p.xz += t * 0.05f;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;	p *= 2.0f;

			  noise /= 1.2f;




		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
			  cloudAltitudeWeight = pow(cloudAltitudeWeight, 0.5f);

		noise *= cloudAltitudeWeight;

		//cloud edge
		float coverage = 0.45f;
			  coverage = mix(coverage, 0.75f, rainStrength);
		float density = 0.5f;
		noise = clamp(noise - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);



		float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);

			  directLightFalloff *= mix(	clamp(pow(noise, 0.9f), 0.0f, 1.0f), 	clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f), 	pow(sunglow, 0.2f));

		vec3 colorDirect = colorSunlight * 10.0f;
		colorDirect *= 1.0f + pow(sunglow, 4.0f) * 555.0f;


		vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;


		vec3 color = mix(colorAmbient, colorDirect, vec3(directLightFalloff));

		vec4 result = vec4(color.rgb, noise);

		return result;
	}
}

void 	CalculateClouds2 (inout vec3 color, inout SurfaceStruct surface)
{

		surface.cloudAlpha = 0.0f;

		vec2 coord = texcoord.st * 2.0f;

		vec4 worldPosition = gbufferModelViewInverse * surface.screenSpacePosition;
			 worldPosition.xyz += cameraPosition.xyz;

		float cloudHeight = 150.0f;
		float cloudDepth  = 60.0f;
		float cloudDensity = 2.25f;

		float startingRayDepth = far - 5.0f;

		float rayDepth = startingRayDepth;

		float rayIncrement = far / 10.0f;

		rayDepth += CalculateDitherPattern1() * rayIncrement;

		int i = 0;

		vec3 cloudColors = colorSunlight;
		vec4 cloudSum = vec4(0.0f);
			 cloudSum.rgb = colorSkylight * 0.2f;
			 cloudSum.rgb = color.rgb;

		float sunglow = CalculateSunglow(surface);

		float cloudDistanceMult = 400.0f / far;


		float surfaceDistance = length(worldPosition.xyz - cameraPosition.xyz);

		while (rayDepth > 0.0f)
		{
			//determine worldspace ray position
			vec4 rayPosition = GetCloudSpacePosition(texcoord.st, rayDepth, cloudDistanceMult);

			float rayDistance = length((rayPosition.xyz - cameraPosition.xyz) / cloudDistanceMult);
			
			#ifdef Three_Clouds
			vec4 proximity =  CloudColors(rayPosition, sunglow, surface.worldLightVector) + CloudColorss(rayPosition, sunglow, surface.worldLightVector) + CloudColorsss(rayPosition, sunglow, surface.worldLightVector);
			#endif
			
			#ifdef New_Clouds
			vec4 proximity =  CloudColor3(rayPosition, sunglow, surface.worldLightVector);proximity.a *= cloudDensity;
			#endif
			
			proximity.a *= cloudDensity;
			
				 if (surfaceDistance < rayDistance * cloudDistanceMult  && surface.mask.sky == 0.0)
				 	proximity.a = 0.0f;


			color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

			surface.cloudAlpha += proximity.a;

			//Increment ray
			rayDepth -= rayIncrement;
			i++;


		}


}


vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness)
{

	float cloudHeight = altitude;
	float cloudDepth  = thickness;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 3000.0f);

	vec3 p = worldPosition.xyz / 300.0f;

		

	
	float t = frameTimeCounter * 1.0f;
		  //t *= 0.001;
	p.x -= t * 0.01f;

	 p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.057f;	vec3 p2 = p;
		  noise += (1.0f - abs(Get3DNoise(p) * 1.0f - 0.5f)) * 0.15f;						p *= 3.0f;	p.xz -= t * 0.035f;	vec3 p3 = p;
		  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.045f;						p *= 3.0f;	p.xz -= t * 0.035f;	vec3 p4 = p;
		  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.015f;						p *= 3.0f;	p.xz -= t * 0.035f;
		  noise += ((Get3DNoise(p))) * 0.015f;												p *= 3.0f;
		  noise += ((Get3DNoise(p))) * 0.006f;
		  noise /= 1.175f;



	const float lightOffset = 0.2f;


	float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0f)), 0.0f, 1.0f);
	float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 50.0f)) / (cloudDepth * 1.0f)), 0.0f, 1.0f);

	float cloudAltitudeWeight = 1.0f;

	float cloudAltitudeWeight2 = 1.0f;

	noise *= cloudAltitudeWeight;

	//cloud edge
	float coverage = 0.39f;
		  coverage = mix(coverage, 0.77f, rainStrength);

		  float dist = length(worldPosition.xz - cameraPosition.xz);
		  coverage *= max(0.0f, 1.0f - dist / 40000.0f);
	float density = 0.8f;
	noise = GetCoverage(coverage, density, noise);




	float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
		  sundiff += Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 0.15f;  	
		  				float largeSundiff = sundiff; 
		  				      largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);
		  sundiff += Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 0.045f;
		  sundiff += Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 0.015f;
		  sundiff *= 1.3f;
		  sundiff *= cloudAltitudeWeight2;
		  sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);
	float firstOrder 	= pow(clamp(sundiff * 1.0f + 1.1f, 0.0f, 1.0f), 12.0f);
	float secondOrder 	= pow(clamp(largeSundiff * 1.0f + 0.9f, 0.0f, 1.0f), 3.0f);



	float directLightFalloff = mix(firstOrder, secondOrder, 0.1f);
	float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

		  directLightFalloff *= anisoBackFactor;
	 	  directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));
	


	vec3 colorDirect = colorSunlight * 0.815f;
		 colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
		 colorDirect *= 1.0f + pow(sunglow, 2.0f) * 300.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);


	vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(heightGradient * 0.0f + 0.15f)) * 0.36f;
		 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
		 colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));
		 colorAmbient *= heightGradient * heightGradient + 0.1f;

	 vec3 colorBounced = colorBouncedSunlight * 0.1f;
	 	 colorBounced *= pow((1.0f - heightGradient), 8.0f);


	directLightFalloff *= 1.0f;
	//directLightFalloff += pow(Get3DNoise(p3), 2.0f) * 0.05f + pow(Get3DNoise(p4), 2.0f) * 0.015f;

	vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

	color *= 1.0f;

	vec4 result = vec4(color.rgb, noise);

	return result;
	
}

vec4 CloudColor2(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness, const bool isShadowPass)
{

	float cloudHeight = altitude;
	float cloudDepth  = thickness;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 9001.0f);

	vec3 p = worldPosition.xyz / 100.0f;

		

	float t = frameTimeCounter * 1.0f;
		  t *= 0.4;


	 p += (Get3DNoise(p * 2.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.10f;

	  p.x -= (Get3DNoise(p * 0.125f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.2f;
	// p.xz -= (Get3DNoise(p * 0.0525f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.7f;


	p.x *= 0.25f;
	p.x -= t * 0.01f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.017f;	p.z += noise * 1.35f;	p.x += noise * 0.5f; 									vec3 p2 = p;
		  noise += (2.0f - abs(Get3DNoise(p) * 2.0f - 0.0f)) * (0.25f);						p *= 3.0f;	p.xz -= t * 0.005f;	p.z += noise * 1.35f;	p.x += noise * 0.5f; 	p.x *= 3.0f;	p.z *= 0.55f;	vec3 p3 = p;
		 	 p.z -= (Get3DNoise(p * 0.25f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.4f;
		  noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.035f);					p *= 3.0f;	p.xz -= t * 0.005f;																					vec3 p4 = p;
		  noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.025f);					p *= 3.0f;	p.xz -= t * 0.005f;
		  if (!isShadowPass)
		  {
		 		noise += ((Get3DNoise(p))) * (0.039f);												p *= 3.0f;
		  		 noise += ((Get3DNoise(p))) * (0.024f);
		  }
		  noise /= 1.575f;

	//cloud edge
	float rainy = mix(wetness, 1.0f, rainStrength);
		  //rainy = 0.0f;
	float coverage = 0.55f + rainy * 0.35f;
		  //coverage = mix(coverage, 0.97f, rainStrength);

		  float dist = length(worldPosition.xz - cameraPosition.xz);
		  coverage *= max(0.0f, 1.0f - dist / mix(10000.0f, 3000.0f, rainStrength));
	float density = 0.0f;

	if (isShadowPass)
	{
		return vec4(GetCoverage(coverage + 0.2f, density + 0.2f, noise));
	}
	else
	{

		noise = GetCoverage(coverage, density, noise);
		noise = noise * noise * (3.0f - 2.0f * noise);

		const float lightOffset = 0.2f;



		float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
			  sundiff += (2.0f - abs(Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 2.0f - 0.0f)) * (0.55f);  	
			  				float largeSundiff = sundiff; 
			  				      largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);
			  sundiff += (3.0f - abs(Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 3.0f - 0.0f)) * (0.065f);
			  sundiff += (3.0f - abs(Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 3.0f - 0.0f)) * (0.025f);
			  sundiff /= 1.5f;
			  sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);
		float secondOrder 	= pow(clamp(sundiff * 1.00f + 1.35f, 0.0f, 1.0f), 7.0f);
		float firstOrder 	= pow(clamp(largeSundiff * 1.1f + 1.56f, 0.0f, 1.0f), 3.0f);



		float directLightFalloff = secondOrder;
		float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

			  directLightFalloff *= anisoBackFactor;
		 	  directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));
		


		vec3 colorDirect = colorSunlight * 0.915f;
			 colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
			 colorDirect *= 1.0f + pow(sunglow, 2.0f) * 100.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);
			 // colorDirect *= 1.0f + pow(1.0f - sunglow, 2.0f) * 30.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);


		vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(0.15f)) * 0.04f;
			 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
			 colorAmbient *= mix(1.0f, ((1.0f - noise) + 0.5f) * 1.4f, rainStrength);
			 // colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));


		directLightFalloff *= 1.0f - rainStrength * 0.75f;


		//directLightFalloff += (pow(Get3DNoise(p3), 2.0f) * 0.5f + pow(Get3DNoise(p3 * 1.5f), 2.0f) * 0.25f) * 0.02f;
		//directLightFalloff *= Get3DNoise(p2);

		vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

		color *= 1.0f;

		// noise *= mix(1.0f, 5.0f, sunglow);

		vec4 result = vec4(color, noise);

		return result;
	}
	
}

void CloudPlane(inout SurfaceStruct surface)
{
	//Initialize view ray
	vec4 worldVector = gbufferModelViewInverse * (-GetScreenSpacePosition(texcoord.st, 1.0f));

	surface.viewRay.dir = normalize(worldVector.xyz);
	surface.viewRay.origin = vec3(0.0f);

	float sunglow = CalculateSunglow(surface);



	float cloudsAltitude = 840.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float density = 1.0f;

	if (cameraPosition.y < cloudsLowerLimit)
	{
		float planeHeight = cloudsUpperLimit;

		float stepSize = 25.5f;
		planeHeight -= cloudsThickness * 0.85f;
		//planeHeight += CalculateDitherPattern1() * stepSize;
		//planeHeight += CalculateDitherPattern() * stepSize;

		//while(planeHeight > cloudsLowerLimit)
		///{
			Plane pl;
			pl.origin = vec3(0.0f, cameraPosition.y - planeHeight, 0.0f);
			pl.normal = vec3(0.0f, 1.0f, 0.0f);

			Intersection i = RayPlaneIntersectionWorld(surface.viewRay, pl);

			if (i.angle < 0.0f)
			{
				if (i.distance < surface.linearDepth || surface.mask.sky > 0.5f)
				{
					 vec4 cloudSample = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
					 	 cloudSample.a = min(1.0f, cloudSample.a * density);

					surface.sky.albedo.rgb = mix(surface.sky.albedo.rgb, cloudSample.rgb, cloudSample.a);

					cloudSample = CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
					cloudSample.a = min(1.0f, cloudSample.a * density);

					surface.sky.albedo.rgb = mix(surface.sky.albedo.rgb, cloudSample.rgb, cloudSample.a);

				}
			}

	}
}

float CloudShadow(in SurfaceStruct surface)
{
	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float planeHeight = cloudsUpperLimit;

	planeHeight -= cloudsThickness * 0.85f;

	Plane pl;
	pl.origin = vec3(0.0f, planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	//Cloud shadow
	Ray surfaceToSun;
	vec4 sunDir = gbufferModelViewInverse * vec4(surface.lightVector, 0.0f);
	surfaceToSun.dir = normalize(sunDir.xyz);
	vec4 surfacePos = gbufferModelViewInverse * surface.screenSpacePosition;
	surfaceToSun.origin = surfacePos.xyz + cameraPosition.xyz;

	Intersection i = RayPlaneIntersection(surfaceToSun, pl);

	float cloudShadow = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;
		  cloudShadow += CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;

		  cloudShadow = min(cloudShadow, 1.0f);
		  cloudShadow = 1.0f - cloudShadow;

	return cloudShadow;
	// return 1.0f;
}



void 	SnowShader(inout SurfaceStruct surface)
{
	float snowFactor = dot(surface.normal, upVector);
		  snowFactor = clamp(snowFactor - 0.1f, 0.0f, 0.05f) / 0.05f;
	surface.albedo = mix(surface.albedo.rgb, vec3(1.0f), vec3(snowFactor));
}

void 	Test(inout vec3 color, inout SurfaceStruct surface)
{
	vec4 rayScreenSpace = GetScreenSpacePosition(texcoord.st, 1.0f);
		 rayScreenSpace = -rayScreenSpace;
	     rayScreenSpace = gbufferModelViewInverse * rayScreenSpace;

	float planeAltitude = 100.0f;

	vec3 rayDir = normalize(rayScreenSpace.xyz);
	vec3 planeOrigin = vec3(0.0f, 1.0f, 0.0f);
	vec3 planeNormal = vec3(0.0f, 1.0f, 0.0f);
	vec3 rayOrigin = vec3(0.0f);

	float denom = dot(rayDir, planeNormal);

	vec3 intersectionPos = vec3(0.0f);

	if (denom > 0.0001f || denom < -0.0001f)
	{
		float planeRayDist = dot((planeOrigin - rayOrigin), planeNormal) / denom;	//How far along the ray that the ray intersected with the plane

		//if (planeRayDist > 0.0f)
		intersectionPos = rayDir * planeRayDist;
		intersectionPos = -intersectionPos;

		intersectionPos.xz *= cameraPosition.y - 100.0f;

		intersectionPos += cameraPosition.xyz;

		intersectionPos.x = mod(intersectionPos.x, 1.0f);
		intersectionPos.y = mod(intersectionPos.y, 1.0f);
		intersectionPos.z = mod(intersectionPos.z, 1.0f);
	}


	color += intersectionPos.xyz * 0.1f;
}

vec3 Contrast(in vec3 color, in float contrast)
{
	float colorLength = length(color);
	vec3 nColor = color / colorLength;

	colorLength = pow(colorLength, contrast);

	return nColor * colorLength;
}

float GetAO(in vec4 screenSpacePosition, in vec3 normal, in vec2 coord, in vec3 dither)
{
	//Determine origin position
	vec3 origin = screenSpacePosition.xyz;

	vec3 randomRotation = normalize(dither.xyz * vec3(2.0f, 2.0f, 1.0f) - vec3(1.0f, 1.0f, 0.0f));

	vec3 tangent = normalize(randomRotation - normal * dot(randomRotation, normal));
	vec3 bitangent = cross(normal, tangent);
	mat3 tbn = mat3(tangent, bitangent, normal);

	float aoRadius   = 0.15f * -screenSpacePosition.z;
		  //aoRadius   = 0.8f;
	float zThickness = 0.15f * -screenSpacePosition.z;
		  //zThickness = 2.2f;

	vec3 	samplePosition 		= vec3(0.0f);
	float 	intersect 			= 0.0f;
	vec4 	sampleScreenSpace 	= vec4(0.0f);
	float 	sampleDepth 		= 0.0f;
	float 	distanceWeight 		= 0.0f;
	float 	finalRadius 		= 0.0f;

	int numRaysPassed = 0;

	float ao = 0.0f;

	for (int i = 0; i < 4; i++)
	{
		vec3 kernel = vec3(texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).r * 2.0f - 1.0f, 
					     texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).g * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).b * 1.0f);
			 kernel = normalize(kernel);
			 kernel *= pow(dither.x + 0.01f, 1.0f);

		samplePosition = tbn * kernel;
		samplePosition = samplePosition * aoRadius + origin;

			sampleScreenSpace = gbufferProjection * vec4(samplePosition, 0.0f);
			sampleScreenSpace.xyz /= sampleScreenSpace.w;
			sampleScreenSpace.xyz = sampleScreenSpace.xyz * 0.5f + 0.5f;

			//Check depth at sample point
			sampleDepth = GetScreenSpacePosition(sampleScreenSpace.xy).z;

			//If point is behind geometry, buildup AO
			if (sampleDepth >= samplePosition.z && sampleDepth - samplePosition.z < zThickness)
			{	
				ao += 1.0f;
			} else {

			}
	}
	ao /= 4;
	ao = 1.0f - ao;
	ao = pow(ao, 2.1f);

	return ao;
}

vec4 BilateralUpsample(const in float scale, in vec2 offset, in float depth, in vec3 normal) 
{
	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	vec4 light = vec4(0.0f);
	float weights = 0.0f;

	for (float i = -0.5f; i <= 0.5f; i += 1.0f)
	{
		for (float j = -0.5f; j <= 0.5f; j += 1.0f)
		{
			vec2 coord = vec2(i, j) * recipres * 2.0f;

			float sampleDepth = GetDepthLinear(texcoord.st + coord * 2.0f * (exp2(scale)));
			vec3 sampleNormal = GetNormals(texcoord.st + coord * 2.0f * (exp2(scale)));
			//float weight = 1.0f / (pow(abs(sampleDepth - depth) * 1000.0f, 2.0f) + 0.001f);
			float weight = clamp(1.0f - abs(sampleDepth - depth) / 2.0f, 0.0f, 1.0f);
				  weight *= max(0.0f, dot(sampleNormal, normal) * 2.0f - 1.0f);
			//weight = 1.0f;

			light +=	pow(texture2DLod(gaux1, (texcoord.st) * (1.0f / exp2(scale )) + 	offset + coord, 1), vec4(2.2f, 2.2f, 2.2f, 1.0f)) * weight;
			
			weights += weight;
		}
	}


	light /= max(0.00001f, weights);

	if (weights < 0.01f)
	{
		light =	pow(texture2DLod(gaux1, (texcoord.st) * (1.0f / exp2(scale 	)) + 	offset, 2), vec4(2.2f, 2.2f, 2.2f, 1.0f));
	}


	// vec3 light =	texture2DLod(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	scale 	)) + 	offset, 2).rgb;


	return light;
}

vec4 Delta(vec3 albedo, vec3 normal, float skylight)
{
	float depth = GetDepthLinear(texcoord.st);

	vec4 delta = BilateralUpsample(1.0f, vec2(0.0f, 0.0f), 		depth, normal);

	delta.rgb = delta.rgb * albedo * colorSunlight;

	delta.rgb *= 5.0f * delta.a * delta.a * (1.0 - rainStrength) * pow(skylight, 0.5);

	return delta;
}
float getnoise(vec2 pos) {
    return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}


vec3 WaterPosition(sampler2D sample, vec2 co, vec3 pos){
	vec3 underwaterpos = vec3(co.st, texture2D(sample, co.st).x);
		 underwaterpos = nvec3(gbufferProjectionInverse * nvec4(underwaterpos * 2.0 - 1.0));
	vec4 worldpositionuw = gbufferModelViewInverse * vec4(underwaterpos, 1.0);	
	vec3 wpos = worldpositionuw.xyz + pos.xyz;
	
	return wpos;
}

vec4 textureSmooth(in sampler2D tex, in vec2 coord)
{
	vec2 res = vec2(64.0f, 64.0f);

	coord *= res;
	coord += 0.5f;

	vec2 whole = floor(coord);
	vec2 part  = fract(coord);

	part.x = part.x * part.x * (3.0f - 2.0f * part.x);
	part.y = part.y * part.y * (3.0f - 2.0f * part.y);
	// part.x = 1.0f - (cos(part.x * 3.1415f) * 0.5f + 0.5f);
	// part.y = 1.0f - (cos(part.y * 3.1415f) * 0.5f + 0.5f);

	coord = whole + part;

	coord -= 0.5f;
	coord /= res;

	return texture2D(tex, coord);

}


float GetWaves(vec3 position, in float scale) {

	float speed = 1.6;

	vec2 p = position.xz / 13.5f;

	p.xy -= position.y / 1000.0f;

	p.x = -p.x;
   

	p.x += (frameTimeCounter / 40.0f) * speed;
	p.y -= (frameTimeCounter / 40.0f) * speed;
    
	float weight = 2.0f;
	float weights = weight;

	float allwaves = 1.0f;

	float wave = textureSmooth(noisetex, (p * vec2(2.0f, 1.2f))  + vec2(0.0f,  p.x * 2.1f) ).x; 			p /= 2.1f; 	/*p *= pow(2.0f, 1.0f);*/ 	p.y -= (frameTimeCounter / 50.0f) * speed; p.x -= (frameTimeCounter / 30.0f) * speed;
	
	allwaves += wave;

	weight = 2.1f;	
	weights += weight;
		  wave = textureSmooth(noisetex, (p * vec2(2.0f, 1.4f))  + vec2(0.0f,  -p.x * 2.1f) ).x;	p /= 1.5f;/*p *= pow(2.0f, 2.0f);*/ 	p.x += (frameTimeCounter / 20.0f) * speed;
		  
		  wave *= weight;
	allwaves += wave;

	weight = 7.25f;	
	weights += weight;	
		  wave = abs(textureSmooth(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  p.x * 1.1f) ).x);		p /= 1.3f; 	p.x -= (frameTimeCounter / 25.0f) * speed;
		
		  wave *= weight;
	allwaves += wave;

	weight = 9.25f;	
	weights += weight;	
		  wave = abs(textureSmooth(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  -p.x * 1.7f) ).x);		p /= 1.9f; 	p.x += (frameTimeCounter / 155.0f) * speed;
		
		  wave *= weight;
	allwaves += wave;

	return allwaves;
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {
	
	//Initialize surface properties required for lighting calculation for any surface that is not part of the sky
	surface.albedo 				= GetAlbedoLinear(texcoord.st);					//Gets the albedo texture
	surface.albedo 				= pow(surface.albedo, vec3(1.0f));

	//surface.albedo = Contrast(surface.albedo, 1.2f);

	//surface.albedo = normalize(surface.albedo) * (pow(length(surface.albedo), 1.2f));

	//surface.albedo 				= vec3(0.8f);
	surface.normal 				= GetNormals(texcoord.st);						//Gets the screen-space normals
	surface.depth  				= GetDepth(texcoord.st);						//Gets the scene depth
	surface.linearDepth 		= ExpToLinearDepth(surface.depth); 				//Get linear scene depth
	surface.screenSpacePosition = GetScreenSpacePosition(texcoord.st); 			//Gets the screen-space position
	surface.viewVector 			= normalize(surface.screenSpacePosition.rgb);	//Gets the view vector
	surface.lightVector 		= lightVector;									//Gets the sunlight vector
	//vec4 wlv 					= gbufferModelViewInverse * vec4(surface.lightVector, 1.0f);
	vec4 wlv 					= shadowModelViewInverse * vec4(0.0f, 0.0f, 1.0f, 0.0f);
	surface.worldLightVector 	= normalize(wlv.xyz);
	surface.upVector 			= upVector;										//Store the up vector





	surface.mask.matIDs 		= GetMaterialIDs(texcoord.st);					//Gets material ids
	CalculateMasks(surface.mask);
	


	surface.albedo *= 1.0f - (surface.mask.sky); 						//Remove the sky from surface albedo, because sky will be handled separately
	
	//surface.water.albedo = surface.albedo * float(surface.mask.water);		//Store underwater albedo
	//surface.albedo *= 1.0f - float(surface.mask.water);						//Remove water from surface albedo to handle water separately
	
	

	//Initialize sky surface properties
	surface.sky.albedo 		= GetAlbedoLinear(texcoord.st) * (min(1.0f, (surface.mask.sky) + (surface.mask.sunspot)));							//Gets the albedo texture for the sky

	surface.sky.tintColor   = vec3(1.0f);
	//surface.sky.tintColor 	= mix(colorSunlight, vec3(colorSunlight.r), vec3(0.8f));									//Initializes the defualt tint color for the sky
	//surface.sky.tintColor 	*= mix(1.0f, 500.0f, timeSkyDark); 													//Boost sky color at night																		//Scale sunglow back to be less intense
	
	surface.sky.sunSpot   	= vec3(float(CalculateSunspot(surface))) * vec3((min(1.0f, (surface.mask.sky) + (surface.mask.sunspot)))) * colorSunlight;
	surface.sky.sunSpot 	*= 1.0f - timeMidnight;
	surface.sky.sunSpot   	*= 500.0f;
	surface.sky.sunSpot 	*= 1.0f - rainStrength;
	//surface.sky.sunSpot     *= 1.0f - timeMidnight;

	AddSkyGradient(surface);
	AddSunglow(surface);
	
	
	
	//Initialize MCLightmap values
	mcLightmap.torch 		= GetLightmapTorch(texcoord.st);	//Gets the lightmap for light coming from emissive blocks


	mcLightmap.sky   		= GetLightmapSky(texcoord.st);		//Gets the lightmap for light coming from the sky
	// mcLightmap.sky 		= 1.0f / pow((1.0f - mcLightmap.sky + 0.00001f), 2.0f);
	// mcLightmap.sky 		-= 1.0f;
	// mcLightmap.sky 		= max(0.0f, mcLightmap.sky);

	mcLightmap.lightning    = 0.0f;								//gets the lightmap for light coming from lightning
	
	
	//Initialize default surface shading attributes
	surface.diffuse.roughness 			= 0.0f;					//Default surface roughness
	surface.diffuse.translucency 		= 0.0f;					//Default surface translucency
	surface.diffuse.translucencyColor 	= vec3(1.0f);			//Default translucency color
	
	surface.specular.specularity 		= GetSpecularity(texcoord.st);	//Gets the reflectance/specularity of the surface
	surface.specular.extraSpecularity 	= 0.0f;							//Default value for extra specularity
	surface.specular.glossiness 		= GetGlossiness(texcoord.st);
	surface.specular.metallic 			= 0.0f;							//Default value of how metallic the surface is
	surface.specular.gain 				= 1.0f;							//Default surface specular gain
	surface.specular.base 				= 0.0f;							//Default reflectance when the surface normal and viewing normal are aligned
	surface.specular.fresnelPower 		= 5.0f;							//Default surface fresnel power
	
	

	
	//Calculate surface shading
	CalculateNdotL(surface);														
	shading.direct  			= CalculateDirectLighting(surface);				//Calculate direct sunlight without visibility check (shadows)
	shading.direct  			= mix(shading.direct, 1.0f, (surface.mask.water)); //Remove shading from water
	shading.sunlightVisibility 	= CalculateSunlightVisibility(surface, shading);					//Calculate shadows and apply them to direct lighting
	shading.direct 				*= shading.sunlightVisibility;							
	shading.direct 				*= mix(1.0f, 0.0f, rainStrength);
	shading.waterDirect 		= shading.direct;
	shading.direct 				*= pow(mcLightmap.sky, 0.1f);
	// shading.bounced 	= CalculateBouncedSunlight(surface);			//Calculate fake bounced sunlight
	// shading.scattered 	= CalculateScatteredSunlight(surface);			//Calculate fake scattered sunlight
	shading.skylight 	= CalculateSkylight(surface);					//Calculate scattered light from sky
	// shading.scatteredUp = CalculateScatteredUpLight(surface);
	shading.heldLight 	= CalculateHeldLightShading(surface);
	
	
	InitializeAO(surface);
	//if (texcoord.s < 0.5f && texcoord.t < 0.5f)
	//CalculateAO(surface);

	float ao = 1.0;

	vec4 delta = vec4(0.0);
	delta.a = 1.0;

	delta = Delta(surface.albedo.rgb, surface.normal.xyz, mcLightmap.sky);

	ao = delta.a;

	
	//Colorize surface shading and store in lightmaps
	lightmap.sunlight 			= vec3(shading.direct) * colorSunlight;
	AddCloudGlow(lightmap.sunlight, surface);
	//lightmap.sunlight 			*= 2.0f - AO;

	lightmap.skylight 			= vec3(mcLightmap.sky);
	lightmap.skylight 			*= mix(colorSkylight, colorBouncedSunlight, vec3(max(0.2f, (1.0f - pow(mcLightmap.sky + 0.13f, 1.0f) * 1.0f)))) + colorBouncedSunlight * (mix(0.4f, 2.8f, 0.0)) * (1.0f - rainStrength);
	//lightmap.skylight 			*= mix(colorSkylight, colorBouncedSunlight, vec3(0.2f));
	lightmap.skylight 			*= shading.skylight;
	lightmap.skylight 			*= mix(1.0f, 5.0f, (surface.mask.clouds));
	lightmap.skylight 			*= mix(1.0f, 50.0f, (surface.mask.clouds) * timeSkyDark);
	lightmap.skylight 			*= surface.ao.skylight;
	//lightmap.skylight 			*= surface.ao.constant * 0.5f + 0.5f;
	lightmap.skylight 			+= mix(colorSkylight, colorSunlight, vec3(0.2f)) * vec3(mcLightmap.sky) * surface.ao.constant * 0.05f;
	lightmap.skylight 			*= mix(1.0f, 0.7f, rainStrength);
	lightmap.skylight 			*= ao;

	// lightmap.bouncedSunlight	= vec3(shading.bounced) * colorBouncedSunlight;
	// lightmap.bouncedSunlight 	*= pow(vec3(mcLightmap.sky), vec3(1.75f));
	// lightmap.bouncedSunlight 	*= mix(1.0f, 0.25f, timeSunriseSunset);
	// lightmap.bouncedSunlight 	*= mix(1.0f, 0.0f, rainStrength);
	// lightmap.bouncedSunlight 	*= surface.ao.bouncedSunlight;
	// lightmap.bouncedSunlight 	*= ao;
	//lightmap.bouncedSunlight 	*= surface.ao.constant * 0.5f + 0.5f;


	// lightmap.scatteredSunlight  = vec3(shading.scattered) * colorScatteredSunlight * (1.0f - rainStrength);
	// lightmap.scatteredSunlight 	*= pow(vec3(mcLightmap.sky), vec3(1.0f));
	// lightmap.scatteredSunlight 	*= ao;
	//lightmap.scatteredSunlight  *= surface.ao.constant * 0.5f + 0.5f;

	lightmap.underwater 		= vec3(mcLightmap.sky) * colorSkylight;

	lightmap.torchlight 		= mcLightmap.torch * colorTorchlight;
	lightmap.torchlight 	 	*= surface.ao.constant * surface.ao.constant;
	lightmap.torchlight 		*= ao;

	lightmap.nolight 			= vec3(0.05f);
	lightmap.nolight 			*= surface.ao.constant;
	lightmap.nolight 			*= ao;

	// lightmap.scatteredUpLight 	= vec3(shading.scatteredUp) * mix(colorSunlight, colorSkylight, vec3(0.3f));
	// lightmap.scatteredUpLight   *= pow(mcLightmap.sky, 0.5f);
	// lightmap.scatteredUpLight 	*= surface.ao.scatteredUpLight;
	// lightmap.scatteredUpLight 	*= mix(1.0f, 0.1f, rainStrength);
	// lightmap.scatteredUpLight 	*= ao;
	//lightmap.scatteredUpLight   *= surface.ao.constant * 0.5f + 0.5f;

	lightmap.heldLight 			= vec3(shading.heldLight);
	lightmap.heldLight 			*= colorTorchlight;
	lightmap.heldLight 			*= heldBlockLightValue / 16.0f;




	//If eye is in water
	if (isEyeInWater > 0) {
		vec3 halfColor = mix(colorWaterMurk, vec3(1.0f), vec3(0.5f));
		lightmap.sunlight *= mcLightmap.sky * halfColor;
		lightmap.skylight *= halfColor;
		lightmap.bouncedSunlight *= 0.0f;
		lightmap.scatteredSunlight *= halfColor;
		lightmap.nolight *= halfColor;
		lightmap.scatteredUpLight *= halfColor;
	}

	surface.albedo.rgb = mix(surface.albedo.rgb, pow(surface.albedo.rgb, vec3(2.0f)), vec3((surface.mask.fire)));
	
	vec3 uvec = surface.screenSpacePosition.xyz - GetScreenSpacePosition(texcoord.st, texture2D(depthtex1, texcoord.xy).x).xyz;
	float UdotU = abs(dot(uvec, surface.normal));
	float depth = length(uvec) * UdotU;
	float NdotF = (dot(normalize(surface.screenSpacePosition.xyz), surface.normal));
	vec3 uColor = vec3(0.28, 0.68, 0.67);
		 uColor = mix(uColor, vec3(0.08, 0.37, 0.45), pow(abs(NdotF), 1.0));
		 uColor = pow(uColor, vec3(2.2)) * 0.025;
		 uColor = uColor * CalculateLuminance(uColor) * 100;
	
	if(surface.mask.water > 0.5)
	surface.albedo = mix(uColor, surface.albedo, max(exp(-depth / 12), 0.0));
	
	//Apply lightmaps to albedo and generate final shaded surface
	final.nolight 			= surface.albedo * lightmap.nolight;
	final.sunlight 			= surface.albedo * lightmap.sunlight;
	final.skylight 			= surface.albedo * lightmap.skylight;
	final.bouncedSunlight 	= surface.albedo * lightmap.bouncedSunlight;
	final.scatteredSunlight = surface.albedo * lightmap.scatteredSunlight;
	final.scatteredUpLight  = surface.albedo * lightmap.scatteredUpLight;
	final.torchlight 		= surface.albedo * lightmap.torchlight;
	final.underwater        = surface.water.albedo * colorWaterBlue;
	// final.underwater 		*= GetUnderwaterLightmapSky(texcoord.st);
	// final.underwater  		+= vec3(0.9f, 1.00f, 0.35f) * float(surface.mask.water) * 0.065f;
	 final.underwater 		*= (lightmap.sunlight * 0.3f) + (lightmap.skylight * 0.06f) + (lightmap.torchlight * 0.0165) + (lightmap.nolight * 0.002f);


	//final.glow.torch 				= pow(surface.albedo, vec3(4.0f)) * float(surface.mask.torch);
	final.glow.lava 				= Glowmap(surface.albedo, surface.mask.lava,      4.0f, vec3(1.0f, 0.05f, 0.001f));

	final.glow.glowstone 			= Glowmap(surface.albedo, surface.mask.glowstone, 2.0f, colorTorchlight);
	//final.glow.glowstone 		   *= (sin(frameTimeCounter * 3.1415f / 3.0f) * 0.5f + 0.5f) * 3.0f + 1.0f;
	final.torchlight 			   *= 1.0f - (surface.mask.glowstone);

	final.glow.fire 				= surface.albedo * (surface.mask.fire);
	final.glow.fire 				= pow(final.glow.fire, vec3(2.0f));

	//final.glow.torch 				= Glowmap(surface.albedo, surface.mask.torch, 	 16.0f, vec3(1.0f, 0.07f, 0.001f));

	//final.glow.torch 				= surface.albedo * float(surface.mask.torch);
	//final.glow.torch 				*= pow(vec3(CalculateLuminance(final.glow.torch)), vec3(6.0f));
	//final.glow.torch 				= pow(final.glow.torch, vec3(1.4f));


	final.glow.torch 				= pow(surface.albedo * (surface.mask.torch), vec3(4.4f));



	//Remove glow items from torchlight to keep control
	final.torchlight *= 1.0f - (surface.mask.lava);

	final.heldLight = lightmap.heldLight * surface.albedo;
	

	//Do night eye effect on outdoor lighting and sky
	DoNightEye(final.sunlight);
	DoNightEye(final.skylight);
	DoNightEye(final.bouncedSunlight);
	DoNightEye(final.scatteredSunlight);
	DoNightEye(surface.sky.albedo);
	DoNightEye(final.underwater);

	DoLowlightEye(final.nolight);



	surface.cloudShadow = 1.0f;
	 float sunlightMult =  timeMidnight + timeSunriseSunset * 3 + timeNoon * 0.9;
	
	//Apply lightmaps to albedo and generate final shaded surface
	vec3 finalComposite = final.sunlight 			* 1.70f * sunlightMult				//Add direct sunlight
						+ final.skylight 			* 0.045f				//Add ambient skylight
						+ final.nolight 			* 0.006f 			//Add base ambient light
						+ final.bouncedSunlight 	* 0.005f 	* sunlightMult				//Add fake bounced sunlight
						+ final.scatteredSunlight 	* 0.02f		* (1.0f - sunlightMult)					//Add fake scattered sunlight
						+ final.scatteredUpLight 	* 0.0015f 	* sunlightMult
						+ final.torchlight 			* 5.0f 			//Add light coming from emissive blocks
						+ final.glow.lava			* 3.6f 			
						+ final.glow.glowstone		* 5.1f 			
						+ final.glow.fire			* 0.25f 			
						+ final.glow.torch			* 3.25f 	
						+ final.heldLight 			* 0.12f		
						;

						
	//Apply sky to final composite
		 surface.sky.albedo *= 5.0f;
		 surface.sky.albedo = surface.sky.albedo * surface.sky.tintColor + surface.sky.sunglow + surface.sky.sunSpot;
		 //CloudPlane(surface);
		 //DoNightEye(surface.sky.albedo);
		 finalComposite 	+= surface.sky.albedo;		//Add sky to final image
		 finalComposite 	+= delta.rgb * sunlightMult;
		 vec4 cloudsTexture = pow(texture2DLod(gaux2, texcoord.st / 4.0, 0).rgba, vec4(2.2, 2.2, 2.2, 1.0));



	//if eye is in water, do underwater fog
	if (isEyeInWater > 0) {
		CalculateUnderwaterFog(surface, finalComposite);
	}

	//CalculateRainFog(finalComposite.rgb, surface);
#ifdef ATMOSPHERIC_FOG	
	AtmosphericScattering(finalComposite.rgb, surface);
#endif

#ifdef VOLUMETRIC_CLOUDS		
	CalculateClouds2(finalComposite.rgb, surface);
#endif	

	//CalculateCloudsSemiPlanar(finalComposite.rgb, surface);


	finalComposite = mix(finalComposite, cloudsTexture.rgb, cloudsTexture.a);



		 // finalComposite = texture2D(gaux1, texcoord.st).rgb * 0.001;

	finalComposite *= 0.0008f;												//Scale image down for HDR
	finalComposite.b *= 1.0f;

	 //TestRaymarch(finalComposite.rgb, surface);
	  //finalComposite.rgb = surface.debug * 0.00004f;

	 finalComposite = pow(finalComposite, vec3(1.0f / 2.2f)); 					//Convert final image into gamma 0.45 space to compensate for gamma 2.2 on displays
	 finalComposite = pow(finalComposite, vec3(1.0f / BANDING_FIX_FACTOR)); 	//Convert final image into banding fix space to help reduce color banding
	

	if (finalComposite.r > 1.0f) {
		finalComposite.r = 0.0f;
	}

	if (finalComposite.g > 1.0f) {
		finalComposite.g = 0.0f;
	}

	if (finalComposite.b > 1.0f) {
		finalComposite.b = 0.0f;
	}

	//finalComposite *= ao;
	
	
	
#ifdef GOD_RAYS

	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
		 tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;

	float gr = 0.0;

		vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy);
			 deltaTextCoord *= 1.0 / float(gr_samples) * gr_density;
		vec2 textCoord = texcoord.st;

		float fallof = 3.0;
		float noise = getnoise(textCoord);

		for(int i=0; i < gr_samples ; i++){
			textCoord -= deltaTextCoord;

			fallof *= GODRAY_LENGTH;
			float sample = step(texture2D(gdepth, textCoord+ deltaTextCoord*noise*gr_noise).r,0.001);
			gr += sample * fallof;
		}

#endif


vec3 underWaterPosition = WaterPosition(depthtex1, texcoord.xy, cameraPosition);
if(surface.mask.water > 0.0){		
finalComposite.rgb += GetWaves(underWaterPosition.xyz, 50.1) * final.sunlight * (timeMidnight * 50 + timeSunriseSunset * 3 + timeNoon * 2.2) * 0.035;
}
finalComposite.rgb += GetWaves(underWaterPosition.xyz, 50.1) * final.skylight * (timeMidnight * 50 + timeSunriseSunset * 3 + timeNoon * 1.2) * 0.01  	*isEyeInWater;


#ifdef GOD_RAYS
	gl_FragData[0] = vec4(finalComposite, (gr/gr_samples));	
#else
	gl_FragData[0] = vec4(finalComposite, 1.0f);
#endif
	gl_FragData[1] = vec4(surface.mask.matIDs, surface.shadow * surface.cloudShadow * pow(mcLightmap.sky, 0.2f), mcLightmap.sky, 1.0f);
	gl_FragData[2] = vec4(surface.specular.specularity, surface.cloudAlpha, surface.specular.glossiness, 1.0f);
	// gl_FragData[4] = vec4(pow(surface.albedo.rgb, vec3(1.0f / 2.2f)), 1.0f);
	// gl_FragData[5] = vec4(surface.normal.rgb * 0.5f + 0.5f, 1.0f);

}
