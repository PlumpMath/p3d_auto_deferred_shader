//GLSL
#version 140
struct p3d_LightSourceParameters
    {
    vec4 position;
    samplerCube shadowMap;
    };
uniform p3d_LightSourceParameters shadowcaster;
uniform mat4 p3d_ProjectionMatrixInverse;
uniform mat4 p3d_ViewProjectionMatrixInverse;
uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ModelViewMatrix;
uniform sampler2D albedo_tex;
uniform sampler2D normal_tex;
uniform sampler2D depth_tex;

uniform mat4 trans_render_to_shadowcaster;

uniform vec4 light;
uniform vec4 light_pos;
//uniform vec2 win_size;

uniform float near;
uniform float bias;

in vec3 N;
in vec3 V;
//in vec4 shadow_uv;

// For each component of v, returns -1 if the component is < 0, else 1
vec2 sign_not_zero(vec2 v)
    {
    // Version with branches (for GLSL < 4.00)
    return vec2(v.x >= 0 ? 1.0 : -1.0, v.y >= 0 ? 1.0 : -1.0);
    }

// Packs a 3-component normal to 2 channels using octahedron normals
vec2 pack_normal_octahedron(vec3 v)
    {
    // Faster version using newer GLSL capatibilities
    v.xy /= dot(abs(v), vec3(1.0));
    // Branch-Less version
    return mix(v.xy, (1.0 - abs(v.yx)) * sign_not_zero(v.xy), step(v.z, 0.0));
    }


// Unpacking from octahedron normals, input is the output from pack_normal_octahedron
vec3 unpack_normal_octahedron(vec2 packed_nrm)
    {
    // Version using newer GLSL capatibilities
    vec3 v = vec3(packed_nrm.xy, 1.0 - abs(packed_nrm.x) - abs(packed_nrm.y));
    // Branch-Less version
    v.xy = mix(v.xy, (1.0 - abs(v.yx)) * sign_not_zero(v.xy), step(v.z, 0));
    return normalize(v);
    }

float soft_shadow_cube(samplerCube tex, vec3 uvw, float z, float bias, float blur)
    {
    float pixel=blur/textureSize(tex, 0).x;
    //float result=float(texture(tex, uvw).r >= (z * 0.5 + 0.5)+bias);
    float result =float(texture(tex,uvw+vec3(1,0,0)*pixel).r >= (z * 0.5 + 0.5)+bias);
    result +=float(texture(tex,uvw+vec3(-1,0,0)*pixel).r >= (z * 0.5 + 0.5)+bias);
    result +=float(texture(tex,uvw+vec3(0,1,0)*pixel).r >= (z * 0.5 + 0.5)+bias);
    result +=float(texture(tex,uvw+vec3(0,-1,0)*pixel).r >= (z * 0.5 + 0.5)+bias);
    result +=float(texture(tex,uvw+vec3(0,0,1)*pixel).r >= (z * 0.5 + 0.5)+bias);
    result +=float(texture(tex,uvw+vec3(0,0,-1)*pixel).r >= (z * 0.5 + 0.5)+bias);
    return result/6.0;
    }


void main()
    {
    vec3 color=vec3(0.0, 0.0, 0.0);
    vec2 win_size=textureSize(depth_tex, 0).xy;
    vec2 uv=gl_FragCoord.xy/win_size;

    vec4 color_tex=texture(albedo_tex, uv);
    vec3 albedo=color_tex.rgb;
    vec4 normal_glow_gloss=texture(normal_tex,uv);
    vec3 normal=unpack_normal_octahedron(normal_glow_gloss.xy);
    float gloss=normal_glow_gloss.a;
    float glow=normal_glow_gloss.b;
    float depth=texture(depth_tex,uv).r * 2.0 - 1.0;

    //vec4 light_view_pos=p3d_ViewMatrix*vec4(light_pos.xyz, 1.0);
    vec4 light_view_pos=shadowcaster.position;

    vec4 view_pos = p3d_ProjectionMatrixInverse * vec4( uv.xy * 2.0 - vec2(1.0), depth, 1.0);
    view_pos.xyz /= view_pos.w;


    vec3 light_color=light.rgb;
    float light_radius=light.w;
    //diffuse
    vec3 light_vec = normalize(light_view_pos.xyz-view_pos.xyz);
    float attenuation=1.0-(pow(distance(view_pos.xyz, light_view_pos.xyz), 2.0)/light_radius);
    //attenuation*=pow(dot(normalize(N),normalize(V)), 2.0);
    //attenuation=clamp(attenuation, 0.0, 1.0);
    color+=light_color*max(dot(normal.xyz,light_vec), 0.0)*attenuation;
    //spec
    vec3 view_vec = normalize(-view_pos.xyz);
    vec3 reflect_vec=normalize(reflect(light_vec,normal.xyz));
    float spec=pow(max(dot(reflect_vec, -view_vec), 0.0), 100.0*gloss)*attenuation*gloss;

    vec4 final=vec4((color*albedo)+light_color*spec, spec+gloss);

    //shadows
    vec4 world_pos = p3d_ViewProjectionMatrixInverse * vec4( uv.xy * 2.0 - vec2(1.0), depth, 1.0);
    vec4 shadow_uv=trans_render_to_shadowcaster*world_pos;
    shadow_uv.xyz=shadow_uv.xyz/shadow_uv.w;
    float ldist = max(abs(shadow_uv.x), max(abs(shadow_uv.y), abs(shadow_uv.z)));
    ldist = ((light_radius+near)/(light_radius-near))+((-2.0*light_radius*near)/(ldist * (light_radius-near)));
    //float shadow= float(texture(shadowcaster.shadowMap, shadow_uv.xyz).r >= (ldist * 0.5 + 0.5)+bias);
    float shadow=soft_shadow_cube( shadowcaster.shadowMap,  shadow_uv.xyz,  ldist,  bias,  50.0*(1.0-attenuation));
    final*=shadow;

    //final=shadow_uv;

    gl_FragData[0]=final;
    //gl_FragData[0]=vec4(shadow, shadow, shadow, 1.0);
    }
