vec4 getFragColor(float stdLight, vec3 _lightDir)  
{  
	if(frag.edge > 0)
	{
		return vec4(0.0,0.0,0.0,1.0);
	}
	vec4 color = pureColor?glColor:texture2D(mainTexture,frag.vTexCoord.st);
	if(enableToon)
	{
		float f = 0.5 * (1.0 - dot( _lightDir, frag.normal ));
		vec2 toonCoord = vec2(0.0, f);
		color = color * texture2D(toonTexture,toonCoord);
	}
	if(enableSpa!=0)
	{
		vec2 spaCoord = (frag.normal.xy + vec2(1.0,1.0))*0.5;
		if(enableSpa==1)
			color = color * texture2D(spaTexture,spaCoord);
		else if(enableSpa==2)
			color = color + texture2D(spaTexture,spaCoord);
		else if(enableSpa==3)
			color = texture2D(spaTexture,spaCoord);
	}
	if(enableLightmap)
	{	
		return stdLight * color * texture2D(lightmapTexture,lightmapCoord);
		//return stdLight * color;
	}
	else
	{
		return stdLight * color;
	}
}  