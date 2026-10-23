time flutter --verbose clean
time flutter --verbose pub cache repair
time flutter --verbose build ios
cd ios
xcodebuild -workspace -allowProvisioningUpdates Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release archive -archivePath $PWD/build/Runner.xcarchive
xcodebuild -exportArchive -allowProvisioningUpdates -archivePath $PWD/build/Runner.xcarchive -exportOptionsPlist exportOptions.plist -exportPath $PWD/build/Runner.ipa
cd ..
cp ios/build/Runner.ipa/Runner.ipa build/Carsworld.ipa
