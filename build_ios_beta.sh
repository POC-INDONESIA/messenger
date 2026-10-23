flutter --verbose clean
# flutter --verbose pub cache repair
flutter --verbose build ios
cd ios
fastlane --verbose beta
cd ..