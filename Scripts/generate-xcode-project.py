#!/usr/bin/env python3
"""Dependency-free deterministic native Xcode project generator."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
objects={}
def ident(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(key,value): objects[ident(key)]=value; return ident(key)
def arr(values): return '('+','.join(values)+(',' if values else '')+')'
def q(s): return '"'+s.replace('"','\\"')+'"'
core_files=sorted((root/'Sources/SnowCore').glob('*.swift'))
app_files=sorted((root/'Sources/SnowPlay').glob('*.swift'))
test_files=sorted((root/'Tests/SnowCoreTests').glob('*.swift'))
def references(files):
 refs=[]; builds=[]
 for f in files:
  path=str(f.relative_to(root)); ref=add('file:'+path,'{isa=PBXFileReference; lastKnownFileType=sourcecode.swift; path='+q(path)+'; sourceTree=SOURCE_ROOT;}')
  refs.append(ref); builds.append(add('build:'+path,'{isa=PBXBuildFile;fileRef='+ref+';}'))
 return refs,builds
core_refs,core_build=references(core_files); app_refs,app_build=references(app_files);test_refs,test_build=references(test_files)
resource=add('resource','{isa=PBXFileReference;lastKnownFileType=folder;path=Sources/SnowPlay/Resources;sourceTree=SOURCE_ROOT;}')
resource_build=add('resource-build','{isa=PBXBuildFile;fileRef='+resource+';}')
products=[]
for name,typ,path in [('core','wrapper.framework','SnowCore.framework'),('app','wrapper.application','SnowPlay.app'),('test','wrapper.cfbundle','SnowCoreTests.xctest')]:
 products.append(add(name+'-product','{isa=PBXFileReference;explicitFileType='+typ+';includeInIndex=0;path='+path+';sourceTree=BUILT_PRODUCTS_DIR;}'))
prod_group=add('products','{isa=PBXGroup;children='+arr(products)+';name=Products;sourceTree="<group>";}')
groups=[]
for name,refs in [('SnowCore',core_refs),('SnowPlay',app_refs+[resource]),('Tests',test_refs)]:
 groups.append(add(name+'-group','{isa=PBXGroup;children='+arr(refs)+';name='+name+';sourceTree="<group>";}'))
main_group=add('main-group','{isa=PBXGroup;children='+arr(groups+[prod_group])+';sourceTree="<group>";}')
project=ident('project')
def config_list(name,settings):
 ids=[]
 for mode in ['Debug','Release']:
  s=dict(settings); s['SWIFT_OPTIMIZATION_LEVEL']='-Onone' if mode=='Debug' else '-O'; s['DEBUG_INFORMATION_FORMAT']='dwarf' if mode=='Debug' else 'dwarf-with-dsym'
  if mode=='Debug': s['ENABLE_TESTABILITY']='YES'
  body=''.join(k+'='+q(v)+';' for k,v in s.items())
  ids.append(add(name+mode,'{isa=XCBuildConfiguration;buildSettings={'+body+'};name='+mode+';}'))
 return add(name+'-configs','{isa=XCConfigurationList;buildConfigurations='+arr(ids)+';defaultConfigurationIsVisible=0;defaultConfigurationName=Release;}')
common={'MACOSX_DEPLOYMENT_TARGET':'13.0','SDKROOT':'macosx','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_STYLE':'Automatic'}
proj_configs=config_list('project',common)
core_configs=config_list('core',{'PRODUCT_NAME':'SnowCore','PRODUCT_BUNDLE_IDENTIFIER':'com.snowplay.core','DEFINES_MODULE':'YES','GENERATE_INFOPLIST_FILE':'YES','SKIP_INSTALL':'YES','DYLIB_INSTALL_NAME_BASE':'@rpath'})
app_configs=config_list('app',{'PRODUCT_NAME':'SnowPlay','PRODUCT_BUNDLE_IDENTIFIER':'com.snowplay.desktop','INFOPLIST_FILE':'Packaging/Info.plist','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks','COMBINE_HIDPI_IMAGES':'YES'})
test_configs=config_list('test',{'PRODUCT_NAME':'SnowCoreTests','PRODUCT_BUNDLE_IDENTIFIER':'com.snowplay.coretests','GENERATE_INFOPLIST_FILE':'YES','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @loader_path/../Frameworks @executable_path/../Frameworks'})
core_target=ident('core-target')
proxy=add('core-proxy','{isa=PBXContainerItemProxy;containerPortal='+project+';proxyType=1;remoteGlobalIDString='+core_target+';remoteInfo=SnowCore;}')
dependency=add('core-dependency','{isa=PBXTargetDependency;target='+core_target+';targetProxy='+proxy+';}')
core_link=add('core-link','{isa=PBXBuildFile;fileRef='+products[0]+';}')
core_embed=add('core-embed','{isa=PBXBuildFile;fileRef='+products[0]+';settings={ATTRIBUTES=(CodeSignOnCopy,RemoveHeadersOnCopy,);};}')
embed=add('embed','{isa=PBXCopyFilesBuildPhase;buildActionMask=2147483647;dstPath="";dstSubfolderSpec=10;files='+arr([core_embed])+';name="Embed Frameworks";runOnlyForDeploymentPostprocessing=0;}')
target_ids=[]
for key,name,builds,config,product,ptype in [('core','SnowCore',core_build,core_configs,products[0],'framework'),('app','SnowPlay',app_build,app_configs,products[1],'application'),('test','SnowCoreTests',test_build,test_configs,products[2],'bundle.unit-test')]:
 sources=add(key+'-sources','{isa=PBXSourcesBuildPhase;buildActionMask=2147483647;files='+arr(builds)+';runOnlyForDeploymentPostprocessing=0;}')
 link=add(key+'-link','{isa=PBXBuildFile;fileRef='+products[0]+';}') if key!='core' else None
 frameworks=add(key+'-frameworks','{isa=PBXFrameworksBuildPhase;buildActionMask=2147483647;files='+arr([link] if link else [])+';runOnlyForDeploymentPostprocessing=0;}')
 phases=[sources,frameworks]
 if key=='app':
  phases.append(add('resources-phase','{isa=PBXResourcesBuildPhase;buildActionMask=2147483647;files='+arr([resource_build])+';runOnlyForDeploymentPostprocessing=0;}')); phases.append(embed)
 if key=='test':
  test_embed_build=add('test-core-embed','{isa=PBXBuildFile;fileRef='+products[0]+';settings={ATTRIBUTES=(CodeSignOnCopy,RemoveHeadersOnCopy,);};}')
  phases.append(add('test-embed','{isa=PBXCopyFilesBuildPhase;buildActionMask=2147483647;dstPath="";dstSubfolderSpec=10;files='+arr([test_embed_build])+';runOnlyForDeploymentPostprocessing=0;}'))
 target_ids.append(add(key+'-target','{isa=PBXNativeTarget;buildConfigurationList='+config+';buildPhases='+arr(phases)+';buildRules=();dependencies='+arr([dependency] if key!='core' else [])+';name='+name+';productName='+name+';productReference='+product+';productType="com.apple.product-type.'+ptype+'";}'))
objects[project]='{isa=PBXProject;attributes={LastUpgradeCheck=1600;};buildConfigurationList='+proj_configs+';compatibilityVersion="Xcode 14.0";developmentRegion=en;knownRegions=(en,Base,);mainGroup='+main_group+';productRefGroup='+prod_group+';projectDirPath="";projectRoot="";targets='+arr(target_ids)+';}'
out=root/'SnowPlay.xcodeproj';out.mkdir(exist_ok=True)
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion=1;classes={};objectVersion=56;objects={\n'+''.join(k+'='+v+';\n' for k,v in objects.items())+'};rootObject='+project+';}\n')
schemes=out/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
(schemes/'SnowPlay.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[1]}" BuildableName="SnowPlay.app" BlueprintName="SnowPlay" ReferencedContainer="container:SnowPlay.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[2]}" BuildableName="SnowCoreTests.xctest" BlueprintName="SnowCoreTests" ReferencedContainer="container:SnowPlay.xcodeproj"/></TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[1]}" BuildableName="SnowPlay.app" BlueprintName="SnowPlay" ReferencedContainer="container:SnowPlay.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Generated native Xcode app, core framework, unit tests and shared scheme')
