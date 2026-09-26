# Sound

C++ class(es): `CScriptBindSound`, `CScriptBind_Sound`
Reached from Lua as `Sound.FunctionName(...)`.
74 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### ActivateAudioDevice

```lua
Sound.ActivateAudioDevice()
```

C++: `int ActivateAudioDevice (IFunctionHandler * pH )`

Activates audio device.

Returns: Bool. Re-Activates the Audiodevice @return bool in case of success

docs: y · retail: unconfirmed

### AddMusicMoodEvent

```lua
Sound.AddMusicMoodEvent(pszMood [, fTimeout])
```

Adds an event for the specified music mood.

| Param | Description |
|---|---|
| pszMood | Music mood name. |
| fTimeout | Timeout value. |

docs: y · retail: unconfirmed

### AddSoundFlags

```lua
Sound.AddSoundFlags()
```

C++: `int AddSoundFlags (IFunctionHandler * pH )`

Remarks: Why is it commented out in.cpp? TN

docs: y · retail: unconfirmed

### CacheAudioFile

```lua
Sound.CacheAudioFile(sName, audioFileCacheType)
```

Caches a single *.fsb file or *.fsb files of a game hint.

| Param | Description |
|---|---|
| char const* const sName | Name of the hint or *.fsb file path. |
| nFileCacheType | file cache type: AFCT_GLOBAL AFCT_LEVEL_SPECIFIC AFCT_GAME_HINT AFCT_GAME_HINT_NO_SERIALIZE AFCT_MUSIC |

docs: y · retail: unconfirmed

### CreateListener

```lua
Sound.CreateListener()
```

C++: `int CreateListener (IFunctionHandler * pH )`

Creates a new Listener

Returns: Listener ID.

docs: y · retail: unconfirmed

### DeactivateAudioDevice

```lua
Sound.DeactivateAudioDevice()
```

C++: `int DeactivateAudioDevice (IFunctionHandler * pH )`

Deactivates the audio device.

Returns: Bool. Deactivates Audiodevice so Wavebanks can be overwritten @return bool in case of success

docs: y · retail: unconfirmed

### EndMusicTheme

```lua
Sound.EndMusicTheme([nThemeFadeType [, nForceEndLimitInSec [, bEndEverything]]])
```

| Param | Description |
|---|---|
| nThemeFadeType | Fade type to stop the theme. Default value is 0. |
| nForceEndLimitInSec | Ending limit in seconds. Default value is 5. |
| bEndEverything | True to end everything, false otherwise. Default value is false. |

docs: y · retail: unconfirmed

### FXEnable

```lua
Sound.FXEnable(pSound, nEffectNumber)
```

Enables the specified effect number.

| Param | Description |
|---|---|
| pSound | Sound identifier. |
| nEffectNumber | Effect number. |

docs: y · retail: unconfirmed

### GetAudioEnvironmentID

```lua
Sound.GetAudioEnvironmentID(char const * const sEnvironmentName)
```

Get the Audio Environment TAudioEnvironmentID (wrapped into a ScriptHandle).

| Param | Description |
|---|---|
| char const* const sEnvironmentName | unique name of an Audio Environment |

Returns: ScriptHandle with the TAudioEnvironmentID value, or nil if the sEnvironmentName is not found.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/AudioUtils.lua`))

### GetAudioRtpcID

```lua
Sound.GetAudioRtpcID(char const * const sRtpcName)
```

Get the RTPC TAudioControlID (wrapped into a ScriptHandle)

| Param | Description |
|---|---|
| char const* const sRtpcName | unique name of an audio RTPC |

Returns: ScriptHandle with the TAudioControlID value, or nil if the sRtpcName is not found.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/AudioUtils.lua`))

### GetAudioSwitchID

```lua
Sound.GetAudioSwitchID(char const * const sSwitchName)
```

Get the switch TAudioControlID (wrapped into a ScriptHandle).

| Param | Description |
|---|---|
| char const* const sSwitchName | unique name of an audio switch |

Returns: ScriptHandle with the TAudioControlID value, or nil if the sSwitchName is not found.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/AudioUtils.lua`))

### GetAudioSwitchStateID

```lua
Sound.GetAudioSwitchStateID(ScriptHandle const hSwitchID, char const * const sSwitchStateName)
```

Get the SwitchState TAudioSwitchStatelID (wrapped into a ScriptHandle).

| Param | Description |
|---|---|
| char const* const sSwitchStateName | unique name of an audio switch state |

Returns: ScriptHandle with the TAudioSwitchStateID value, or nil if the sSwitchStateName is not found.

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/AudioUtils.lua`))

### GetAudioTriggerID

```lua
Sound.GetAudioTriggerID(char const * const sTriggerName)
```

Get the trigger TAudioControlID (wrapped into a ScriptHandle).

| Param | Description |
|---|---|
| char const* const sTriggerName | unique name of an audio trigger |

Returns: ScriptHandle with the TAudioControlID value, or nil if the sTriggerName is not found.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/AudioUtils.lua`))

### GetDirectionalAttenuationMaxScale

```lua
Sound.GetDirectionalAttenuationMaxScale()
```

C++: `int GetDirectionalAttenuationMaxScale (IFunctionHandler * pH )`

Gets the maximum scale of the directional attenuation.

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
Sound.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Sound.

docs: y · retail: unconfirmed

### GetMusicMoods

```lua
Sound.GetMusicMoods(pszTheme)
```

Gets the music moods for the specified music theme.

| Param | Description |
|---|---|
| pszTheme | Theme name. |

docs: y · retail: unconfirmed

### GetMusicStatus

```lua
Sound.GetMusicStatus()
```

C++: `int GetMusicStatus (IFunctionHandler * pH )`

Gets the music status and logs the value to the console.

docs: y · retail: unconfirmed

### GetMusicThemes

```lua
Sound.GetMusicThemes()
```

C++: `int GetMusicThemes (IFunctionHandler * pH )`

Gets the music themes.

docs: y · retail: unconfirmed

### GetSoundLength

```lua
Sound.GetSoundLength(pSound)
```

Gets the sound length in seconds.

| Param | Description |
|---|---|
| pSound | Sound identifier. |

docs: y · retail: unconfirmed

### GetSoundMoodFade

```lua
Sound.GetSoundMoodFade(sSoundMoodName)
```

Gets the fade value for the specified sound mood.

Get the SoundMood fade value

| Param | Description |
|---|---|
| const char * sSoundMoodName | Sound mood name. |

docs: y · retail: unconfirmed

### GetSoundVolume

```lua
Sound.GetSoundVolume(sound)
```

Gets sound volume.

| Param | Description |
|---|---|
| sound | Sound identifier. |

Returns: Float. retrieve the volume of a sound @param nID ID of the sound

docs: y · retail: unconfirmed

### IsEvent

```lua
Sound.IsEvent()
```

C++: `int IsEvent (IFunctionHandler * pH , ScriptHandle SoundID )`

Checks if the sound is an event. Checks for EVENT flag.

Determine if a sound has the event flag @param nID ID of the sound @return nil or not nil

docs: y · retail: unconfirmed

### IsInMusicMood

```lua
Sound.IsInMusicMood(pszMood)
```

Checks if we are currently playing the specified music mood.

| Param | Description |
|---|---|
| pszMood | Music mood name. |

docs: y · retail: unconfirmed

### IsInMusicTheme

```lua
Sound.IsInMusicTheme(pszTheme)
```

Checks if we are currently playing the specified music theme.

| Param | Description |
|---|---|
| pszTheme | Theme name. |

docs: y · retail: unconfirmed

### IsPlaying

```lua
Sound.IsPlaying()
```

C++: `int IsPlaying (IFunctionHandler * pH )`

Checks if the sound is playing.

Returns: Integer. Determine if a sound is still playing @param nID ID of the sound @return nil or not nil

docs: y · retail: confirmed (vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### IsSoundLooped

```lua
Sound.IsSoundLooped(sound)
```

will return false also if the given soundid does not exist

obtain the looping status of a sound @param nID ID of the sound

| Param | Description |
|---|---|
| sound | Sound identifier. |

docs: y · retail: unconfirmed

### IsVoice

```lua
Sound.IsVoice()
```

C++: `int IsVoice (IFunctionHandler * pH , ScriptHandle SoundID )`

Checks if the sound is a voice. Checks for VOICE flag.

Determine if a sound has the voice flag @param nID ID of the sound @return nil or not nil

docs: y · retail: unconfirmed

### LoadMusic

```lua
Sound.LoadMusic(pszFilename)
```

| Param | Description |
|---|---|
| pszFilename | Xml file name containing the music information. |

Returns: Bool.

docs: y · retail: unconfirmed

### LoadSound

```lua
Sound.LoadSound(sound [,flags [,volume [, min [, clipDistance [, priority [, group]]]]]])
```

Loads a 3D sound.

| Param | Description |
|---|---|
| sound | Sound name. |
| flags | Sound flags. |
| volume | Volume. |
| min | Minimum distance. |
| clipDistance | Clip distance. |
| priority | Priority of the sound. |
| group | Group. |

Returns: Integer. Load a 3D sound @param sSound filename of the sound @param nFlags flags :) [optional] @param nFlagsExtended extended flags :) [optional] @param fVolume [optional] @param nMinDistance [optional] @param nMaxDistance [optional] @return nil or sound ID in case of success

docs: y · retail: unconfirmed

### LoadStreamSound

```lua
Sound.LoadStreamSound(sound, flags)
```

Loads a stream sound.

| Param | Description |
|---|---|
| sound | Sound name. |
| flags | Sound flags. |

Returns: Integer. Load a streaming sound @param sSound filename of the sound @return nil or sound ID in case of success

docs: y · retail: unconfirmed

### Play

```lua
Sound.Play(sGroupAndSoundName, vPos, nSoundFlags)
```

Uses the sound definition of the Handle to play a sound at the position vPos . It returns a unique SoundID that is valid as long as the sound is played.

| Param | Description |
|---|---|
| Vec3 vPos | Position where to play sound. |
| uint32 nSoundFlags | Sound flags, specify how to play sound. |
| uint32 nSoundFlagsExtended | Extended sound flags, specify how to play sound. |
| uint32 nSemantic | Semantical information what this sound is. |
| sGroupAndSoundName | SoundGroup name of the sound definition or direct filename of a sound |

Returns: SoundID. Uses the sound definition of the Handle to play a sound at the position vPos . It returns a unique SoundID that is valid as long as the sound is played.

docs: y · retail: confirmed (vanilla×21)

### PlayEx

```lua
Sound.PlayEx(sGroupAndSoundName, nSoundFlags, fVolume, pos, minRadius, maxRadius)
```

Play sound file.

| Param | Description |
|---|---|
| Vec3 vPos | Position where to play sound. |
| uint32 nSoundFlags | Sound flags, specify how to play sound. |
| uint32 nSoundFlagsExtended | Extended sound flags, specify how to play sound. |
| float fVolume | The sound's volume between 0-1 |
| float minRadius | min radius |
| float maxRadius | max radius |
| uint32 nSemantic | Semantical information what this sound is. |
| sGroupAndSoundName | SoundGroup name of the sound definition or direct filename of a sound |

Returns: SoundID. for the new group sound param settings

docs: y · retail: unconfirmed

### PlayPattern

```lua
Sound.PlayPattern(pszPattern, bStopPrevious, bPlaySynched)
```

Play the named pattern

| Param | Description |
|---|---|
| pszPattern | Pattern name. |
| bStopPrevious | True to stop the previous pattern, false otherwise. |
| bPlaySynched | True to play the pattern synched, false otherwise. |

docs: y · retail: unconfirmed

### PlaySound

```lua
Sound.PlaySound(ISound *sound, float volumeScale)
```

Plays a sound.

Load a streaming sound @param sSound filename of the sound @return nil or sound ID in case of success

int CScriptBind_Sound::LoadStreamSoundLocalized(IFunctionHandler *pH) { if (pH->GetParamCount() GetParamCount()>2) { m_pSS->RaiseError("System.LoadStreamSound wrong number of arguments"); return pH->EndFunction(); };

const char *sSound; // int nID; ISound *pSound; pH->GetParam(1,sSound);

int nFlags=0; if (pH->GetParamCount()>1) pH->GetParam(2, nFlags);

string szPath;

ICVar *g_language = gEnv->pConsole->GetCVar("g_language"); assert(g_language);

szPath = "LANGUAGES/"; szPath += g_language->GetString(); szPath += "/"; szPath += sSound;

pSound = m_pSoundSystem->LoadSound(szPath.c_str(),FLAG_SOUND_STREAM | nFlags); if (pSound) { pSound->AddRef();

return pH->EndFunction(ScriptHandle(pSound)); }

return pH->EndFunction();

}

////////////////////////////////////////////////////////////////////////////// ////////////////////////////////////////////////////////////////////////////// ! Start playing a sound, loops is if enabled @param nID ID of the sound @see CScriptBind_Sound::SetSoundLoop

| Param | Description |
|---|---|
| sound | Sound identifier. |
| volumeScale | Volume scale amount. |

docs: y · retail: confirmed (vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/BreakableObject.lua`))

### PlayStinger

```lua
Sound.PlayStinger()
```

C++: `int PlayStinger (IFunctionHandler * pH )`

Plays stinger.

docs: y · retail: unconfirmed

### Precache

```lua
Sound.Precache(sGroupAndSoundName, nPrecacheFlags)
```

Precaches the sound data used by a sound definition Depending on additional flags and current settings may load the sound data into the memory for later usage. Precaching is optional, sound system can also play not cached sounds, but it can cause small delay before sound playing starts.

| Param | Description |
|---|---|
| uint32 nPrecacheFlags | Precache flags, specify sound file caching priority. Precaches the sound data used by a sound definition Depending on additional flags and current settings may load the sound data into the memory for later usage. Precaching is optional, sound system can also play not cached sounds, but it can cause small delay before sound playing starts. |
| sGroupAndSoundName | SoundGroup name of the sound definition or direct filename the sound data should be loaded |

docs: y · retail: unconfirmed

### RegisterSoundMood

```lua
Sound.RegisterSoundMood(sSoundMoodName, fFade [, nFadeTimeInMS])
```

Updates the specified sound mood.

| Param | Description |
|---|---|
| float fFade | Fade value. |
| sSoundMoodName | Sound mood name. |
| nFadeTimeInMs | Fade time in milliseconds. Default value 0. |

Returns: Bool. Updates a SoundMood current fade ratio (0-1)

docs: y · retail: unconfirmed

### RegisterWeightedEaxEnvironment

```lua
Sound.RegisterWeightedEaxEnvironment(sPresetName, nFullEffectWhenInside, nFlags)
```

Registers a weighted EAX (Environmental Audio Extension) environment.

Registers an EAX Preset Area with as being active //! morphing of several EAX Preset Areas is done internally //! Registering the same Preset multiple time will only overwrite the old one @param nPreset one of the presets

| Param | Description |
|---|---|
| sPresetName | Preset name. |
| nFullEffectWhenInside | . |
| nFlags | . |

Returns: Bool.

docs: y · retail: unconfirmed

### RemoveCachedAudioFile

```lua
Sound.RemoveCachedAudioFile(sName, bNow)
```

Removes a single *.fsb file or *.fsb files of a game hint.

| Param | Description |
|---|---|
| char const* const sName | Name of the hint or *.fsb file path. |
| bool bNow | Indicates if the file(s) is(are) supposed to be removed immediately or gracefully when the sound system decides so. |

docs: y · retail: unconfirmed

### RemoveListener

```lua
Sound.RemoveListener(nListenerID)
```

Removes a Listener

| Param | Description |
|---|---|
| int nListenerID | ID of the Listener to be removed |

Returns: bResult - true/false if Listener was removed successfully

docs: y · retail: unconfirmed

### SerializeMusicInternal

```lua
Sound.SerializeMusicInternal([bSave])
```

Serializes the music internal.

| Param | Description |
|---|---|
| bSave | True to serialize the music internal, false otherwise. Default value is false. |

docs: y · retail: unconfirmed

### SetAudioRtpcValue

```lua
Sound.SetAudioRtpcValue(hRtpcID, fValue)
```

Globally sets the specified audio RTPC to the specified value

| Param | Description |
|---|---|
| ScriptHandle const hRtpcID | the audio RTPC ID handle |
| float const fValue | the RTPC value |

Returns: nil

docs: y · retail: confirmed (runtime dump, vanilla×6 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Sound/AudioAreaAmbience.lua`))

### SetDefaultMusicMood

```lua
Sound.SetDefaultMusicMood(pszMood)
```

Sets the specified music mood as the default mood.

| Param | Description |
|---|---|
| pszMood | Music mood name. |

docs: y · retail: unconfirmed

### SetDirectionalAttenuation

```lua
Sound.SetDirectionalAttenuation(vPos, vDir, fConeInRadians)
```

Sets a directional attenuation of the sounds.

| Param | Description |
|---|---|
| vPos | Position vector. |
| vDir | Direction vector for the attenuation. |
| fConeInRadians | Angle of the cone that represents the attenuation. |

docs: y · retail: unconfirmed

### SetFadeTime

```lua
Sound.SetFadeTime(sound, fadeGoal, fadeTimeInMS)
```

Sets the fade time for the sound.

| Param | Description |
|---|---|
| sound | Sound identifier. |
| fadeGoal | Final value for the sound fading. |
| fadeTimeInMS | Fading time in millisecond. |

Returns: Time in milliseconds; Set fade (in) time of a sound @param iSoundID ID of the sound @param nFadeTimeInMs fade time

docs: y · retail: unconfirmed

### SetFXSetParamEQ

```lua
Sound.SetFXSetParamEQ(pSound, fCenter, fBandwidth, fGain)
```

Sets some parameters to the sound effect.

| Param | Description |
|---|---|
| pSound | Sound identifier. |
| fCenter | Sound center. |
| fBandwidth | Sound bandwidth. |
| fGain | Sound gain. |

docs: y · retail: unconfirmed

### SetListener

```lua
Sound.SetListener(nListenerID, vPos, vForward, vTop, bActive, fRecord, vVel)
```

Sets attributes to a Listener

| Param | Description |
|---|---|
| int nListenerID | ID of the Listener to be removed |
| Vec3 vPos | Position of the Listener |
| Vec3 vVel | Velocity for Doppler, (0,0,0) to disable or leave out for automatic calculation |
| Vec3 vForward | a Lookat vector of the Listener |
| Vec3 vTop | a up vector of the Listener |
| bool bActive | state of Listener (active/unactive) |
| float fRecord | input signal strength [0.0-1.0] to fade in and out |

Returns: bResult - true/false if Listener was successfully changed

docs: y · retail: unconfirmed

### SetMasterMusicEffectsVolume

```lua
Sound.SetMasterMusicEffectsVolume(newMusicVol)
```

Set the master volume for music effects.

| Param | Description |
|---|---|
| newMusicVol | New master music effect volume value. allows effects on music volume |

docs: y · retail: unconfirmed

### SetMasterVolumeScale

```lua
Sound.SetMasterVolumeScale(scale)
```

Sets the master volume scale.

| Param | Description |
|---|---|
| scale | Master volume scale value for the sound. |

docs: y · retail: unconfirmed

### SetMenuMusic

```lua
Sound.SetMenuMusic(bPlayMenuMusic, pszTheme, pszMood)
```

Play (or don't) the specified music on the menu screen.

| Param | Description |
|---|---|
| bPlayMenuMusic | True to play music in the menu, false otherwise. |
| pszMood | Music mood name. |
| pszTheme | Theme name. |

docs: y · retail: unconfirmed

### SetMinMaxDistance

```lua
Sound.SetMinMaxDistance(sound, minDist, maxDist)
```

Sets the minimum and the maximum distances for the sound.

Set distance attenuation of a sound @param iSoundID ID of the sound @param fMinDist Minimum distance, normally 0 @param fMaxDist Maximum distance at which the sound can be heard

| Param | Description |
|---|---|
| sound | Sound identifier. |
| minDist | Minimum distance. |
| maxDist | Maximum distance. |

docs: y · retail: confirmed (vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/BreakableObject.lua`))

### SetMusicMood

```lua
Sound.SetMusicMood(pszMood [, bPlayFromStart [, bForceChange]])
```

Sets the specified music mood.

| Param | Description |
|---|---|
| pszMood | Music mood name. |
| bPlayFromStart | True to play from start, false otherwise. Default value is true. |
| bForceChange | True to force the music mood change, false otherwise. Default value is false. |

docs: y · retail: unconfirmed

### SetMusicTheme

```lua
Sound.SetMusicTheme(pszTheme [, bForceChange [, bKeepMood [, nDelayInSec]]])
```

Sets the music theme.

| Param | Description |
|---|---|
| pszTheme | Theme name. |
| bForceChange | True to force the theme change, false otherwise. Default value is false. |
| bKeepMood | True to keep the sound mood, false otherwise. Default value is false. |
| nDelayInSec | Delay in second to change the theme. Default value is -1. |

docs: y · retail: unconfirmed

### SetObstructionOffset

```lua
Sound.SetObstructionOffset(fOffsetInMeters)
```

Sets the audio obstruction offset in meters in regards to the origin (sound emitter).

| Param | Description |
|---|---|
| fOffsetInMeters | obstruction offset in meters. |

docs: y · retail: unconfirmed

### SetParameterValue

```lua
Sound.SetParameterValue(SoundID, sParameterName, fParameterValue)
```

Changes a parameter value of a specific sound (if supported)

| Param | Description |
|---|---|
| ScriptHandle SoundID | unique SoundID of the sound |
| const char * sParameterName | name of the parameter to be changed ("distance"/"pitch") |
| float fParameterValue | value of the parameter to be set, always float |
| nSemantic | Semantical information what this sound is. |

Returns: bool - returns true if the SoundID was valid and the parameter value could be set

docs: y · retail: unconfirmed

### SetPauseAllPlaying

```lua
Sound.SetPauseAllPlaying(bPause)
```

Sets/unsets pause for all the playing sounds.

| Param | Description |
|---|---|
| bool bPause | True to pause all the playing sounds, false to resume them. |

docs: y · retail: unconfirmed

### SetSoundFrequency

```lua
Sound.SetSoundFrequency(sound, frequency)
```

Sets the sound frequency.

Changes the pitch of a sound sound @param nID ID of the sound @param nFrequency Frequency, value range is between 0 and 1000

| Param | Description |
|---|---|
| sound | Sound identifier. |
| frequency | Sound frequency. |

docs: y · retail: unconfirmed

### SetSoundLoop

```lua
Sound.SetSoundLoop(sound)
```

Sets the loop flag to a sound.

Change the looping status of a looped sound @param nID ID of the sound @param nFlag 1/0 to enable/disable looping

| Param | Description |
|---|---|
| sound | Sound identifier. |
| flags | Sound flags to activates/deactivates the loop playback. |

docs: y · retail: confirmed (vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/BreakableObject.lua`))

### SetSoundPaused

```lua
Sound.SetSoundPaused(sound, paused)
```

Pauses/resumes the sound.

Sets the Pause state of a sound @param nID ID of the sound @param bPaused State of Pause Mode

| Param | Description |
|---|---|
| sound | Sound identifier. |
| paused | True to pause the sound, false to resume it. |

docs: y · retail: unconfirmed

### SetSoundPitching

```lua
Sound.SetSoundPitching(sound, pitching)
```

Sets the sound pitching.

| Param | Description |
|---|---|
| sound | Sound identifier. |
| pitching | Sound pitching. |

docs: y · retail: unconfirmed

### SetSoundPosition

```lua
Sound.SetSoundPosition(ISound* sound, Vect3 pos)
```

Sets the position of the sound. nSoundHandle can be SoundID or Ptr.

Change the position of a 3D sound @param nID ID of the sound @param v3d Three component vector containing the position @see CScriptBind_Sound::Load3DSound

| Param | Description |
|---|---|
| sound | Sound identifier. |
| pos | Position of the sound. |

docs: y · retail: confirmed (vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/BreakableObject.lua`))

### SetSoundRatio

```lua
Sound.SetSoundRatio(pSound, fRatio)
```

Sets the sound ratio.

| Param | Description |
|---|---|
| pSound | Sound identifier. |
| fRatio | Sound ratio. |

docs: y · retail: unconfirmed

### SetSoundRelative

```lua
Sound.SetSoundRelative(ISound* sound, bool isRelative)
```

Sets/unsets the RELATIVE Flag. If unset, a new valid position has to be set, or the sound stays at the last listener position.

int CScriptBind_Sound::SetLoopPoints(IFunctionHandler *pH) { SCRIPT_CHECK_PARAMETERS(3);

int nID = 0, iLoopPt1, iLoopPt2; int nCookie=0; _smart_ptrpSound = GetSoundPtr(pH,1);

pH->GetParam(2, iLoopPt1); pH->GetParam(3, iLoopPt2); if (pSound) pSound->SetLoopPoints(iLoopPt1, iLoopPt2);

return pH->EndFunction(); }

int CScriptBind_Sound::AddSoundFlags(IFunctionHandler *pH) { int iFlags; int nCookie=0; ISound *pISound = NULL; SCRIPT_CHECK_PARAMETERS(2);

pH->GetParamUDVal(1,(int &)pISound,nCookie); pH->GetParam(2, iFlags);

if (pISound && (nCookie==USER_DATA_SOUND)) pISound->AddFlags(iFlags);

return pH->EndFunction();

| Param | Description |
|---|---|
| sound | Sound identifier. |
| isRelative | True if the pause is relative, false otherwise. |

docs: y · retail: unconfirmed

### SetSoundSpeed

```lua
Sound.SetSoundSpeed(ISound* sound, Vect3 speed)
```

Sets sound speed.

Change the velocity of a sound @param nID ID of the sound @param v3d Three component vector containing the velocity for each axis

| Param | Description |
|---|---|
| sound | Sound identifier. |
| speed | Sound speed. |

docs: y · retail: unconfirmed

### SetSoundVolume

```lua
Sound.SetSoundVolume(sound, volume)
```

Sets sound volume.

Change the volume of a sound @param nID ID of the sound @param fVolume volume between 0 and 1

| Param | Description |
|---|---|
| sound | Sound identifier. |
| volume | Volume amount. |

docs: y · retail: confirmed (vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/BreakableObject.lua`))

### SetWeatherCondition

```lua
Sound.SetWeatherCondition(fWeatherTemperatureInCelsius, fWeatherHumidityAsPercent, fWeatherInversion)
```

Sets the weather condition.

| Param | Description |
|---|---|
| fWeatherTemperatureInCelsius | Weather temperature in Celsius. |
| fWeatherHumidityAsPercent | Weather humidity as percentage. |
| fWeatherInversion | Weather inversion. |

docs: y · retail: unconfirmed

### Silence

```lua
Sound.Silence()
```

C++: `int Silence (IFunctionHandler * pH )`

Silences the sound.

Returns: Bool. Silence to the whole SoundSystem @return bool in case of success

docs: y · retail: unconfirmed

### StopSound

```lua
Sound.StopSound(sound)
```

Stops the sound. nSoundHandle can be SoundID or Ptr.

Stop playing a sound @param nID ID of the sound

| Param | Description |
|---|---|
| sound | Sound identifier. |

docs: y · retail: confirmed (vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/BreakableObject.lua`))

### UnloadMusic

```lua
Sound.UnloadMusic()
```

C++: `int UnloadMusic (IFunctionHandler * pH )`

Unloads the music.

docs: y · retail: unconfirmed

### UnloadProjects

```lua
Sound.UnloadProjects()
```

C++: `int UnloadProjects (IFunctionHandler * pH )`

Unloads the projects.

Returns: Bool. Unloads all projects so Wavebanks/Project files can be overwritten @return bool in case of success

docs: y · retail: unconfirmed

### UnregisterSoundMood

```lua
Sound.UnregisterSoundMood(sSoundMoodName)
```

Unregisters the specified sound mood.

| Param | Description |
|---|---|
| sSoundMoodName | Sound mood name. |

Returns: Bool. Unregisters a SoundMood

docs: y · retail: unconfirmed

### UnregisterWeightedEaxEnvironment

```lua
Sound.UnregisterWeightedEaxEnvironment(sPresetName, entityId)
```

Unregisters a weighted EAX (Environmental Audio Extension) environment.

Unregisters an active EAX Preset Area

| Param | Description |
|---|---|
| sPresetName | Preset name. |
| entityId | Entity identifier. |

Returns: Bool.

docs: y · retail: unconfirmed

### UpdateSoundSystem

```lua
Sound.UpdateSoundSystem()
```

C++: `int UpdateSoundSystem (IFunctionHandler * pH )`

Updates the sound system if needed ambient volumes call this to fix the issue with beaming to Visareas with sound

fix issue with beaming to Visareas with sound

docs: y · retail: unconfirmed

### UpdateWeightedEaxEnvironment

```lua
Sound.UpdateWeightedEaxEnvironment(sPresetName, fWeight)
```

Updates a weighted EAX (Environmental Audio Extension) environment.

Updates an EAX Preset Area with the current blending ratio (0-1)

| Param | Description |
|---|---|
| sPresetName | Preset name. |
| fWeight | . |

Returns: Bool.

docs: y · retail: unconfirmed
