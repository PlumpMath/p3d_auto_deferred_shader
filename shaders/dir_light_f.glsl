//GLSL
#version 140
uniform sampler2D depth_tex;
uniform sampler2D normal_tex;
uniform sampler2D albedo_tex;
uniform sampler2D lit_tex;
uniform mat4 trans_apiclip_of_camera_to_apiview_of_camera;
#ifndef NUM_LIGHTS
uniform vec3 light_color;
uniform vec3 direction;
in vec4 light_direction;
#endif
#ifdef NUM_LIGHTS
uniform vec3 light_color [NUM_LIGHTS];
uniform vec3 direction [NUM_LIGHTS];
in vec4 light_direction[NUM_LIGHTS];
#endif


in vec2 uv;


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

vec3 getPosition(vec2 uv)
    {
    float depth=texture(depth_tex,uv).r * 2.0 - 1.0;
    vec4 view_pos = trans_apiclip_of_camera_to_apiview_of_camera * vec4( uv.xy * 2.0 - vec2(1.0), depth, 1.0);
    view_pos.xyz /= view_pos.w;
    return view_pos.xyz;
    }


void main()
    {
    vec4 pre_light_tex=texture(lit_tex, uv);
    vec4 color_tex=texture(albedo_tex, uv);
    vec3 albedo=color_tex.rgb;
    vec4 normal_glow_gloss=texture(normal_tex,uv);
    vec3 normal=unpack_normal_octahedron(normal_glow_gloss.xy);
    float gloss=normal_glow_gloss.a;
    float glow=normal_glow_gloss.b;

    vec3 view_pos =getPosition(uv);

    vec3 color=vec3(0.0, 0.0, 0.0);
    vec3 light_vec;
    vec3 view_vec;
    vec3 reflect_vec;
    float spec=0.0;
    vec3 final_spec=vec3(0.0, 0.0, 0.0);
    #ifndef NUM_LIGHTS
        light_vec = normalize(light_direction.xyz);
        #ifdef HALFLAMBERT
        color+=light_color*pow(dot(normal.xyz,light_vec)*0.5+0.5, HALFLAMBERT);
        #endif
        #ifndef HALFLAMBERT
        color+=light_color*max(dot(normal.xyz,light_vec), 0.0);
        #endif
        //spec
        //view_vec = normalize(-view_pos.xyz);
        //reflect_vec=normalize(reflect(light_vec,normal.xyz));
        //spec=pow(max(dot(reflect_vec, -view_vec), 0.0), 100.0*gloss)*gloss;
        //final_spec=light_color*spec;
    #endif
    #ifdef NUM_LIGHTS
        for (int i=0; i<NUM_LIGHTS; ++i)
            {
            light_vec = normalize(light_direction[i].xyz);
            #ifdef HALFLAMBERT
            color+=light_color[i]*pow(dot(normal.xyz,light_vec)*0.5+0.5, HALFLAMBERT);
            #endif
            #ifndef HALFLAMBERT
            color+=light_color[i]*max(dot(normal.xyz,light_vec), 0.0);
            #endif
            //spec
            //view_vec = normalize(-view_pos.xyz);
            //reflect_vec=normalize(reflect(light_vec,normal.xyz));
            //spec+=pow(max(dot(reflect_vec, -view_vec), 0.0), 100.0*gloss)*gloss;
            //final_spec+=light_color[i]*spec;
            }
    #endif

    //vec4 final=pre_light_tex+vec4((color*albedo)+final_spec, spec+gloss);
    vec4 final=pre_light_tex+vec4((color*albedo), gloss);

    final.rgb+=albedo*glow;

    gl_FragData[0]=final;
    }

