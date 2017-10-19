const fs = require('fs');
const path = require('path');
const glob = require("glob");
const variables = require("./variables.js");
const findUsingLibraryFor = require("./find-libraries-usage.js");

function addLibraries(parentDir, inputFileContent, srcFiles, cb) {
	let updatedFileContent = inputFileContent;
	let usingLibrariesFound = 0;
	findUsingLibraryFor(updatedFileContent, function(usingLibraries) {
		for (let k = 0; k < usingLibraries.length; k++) {
			let usingLibraryName = usingLibraries[k];
			for (let j = 0; j < srcFiles.length; j++) {
				let fileContent = fs.readFileSync(srcFiles[j], "utf8");
				if (fileContent.indexOf("library " + usingLibraryName) > -1) {
					if (!variables.importedSrcFiles.hasOwnProperty(srcFiles[j])) {
						updatedFileContent = fileContent + updatedFileContent;
						variables.importedSrcFiles[path.basename(srcFiles[j])] = fileContent;
						srcFiles.splice(j,1);
						usingLibrariesFound++;
					}
					break;
				}
			}
		}

		if (usingLibraries.length > usingLibrariesFound) {
			if (parentDir.lastIndexOf("/") > -1) {
				parentDir = parentDir.substring(0, parentDir.lastIndexOf("/"));
				glob(parentDir + "/**/*.sol", function(err, srcFiles) {
					addLibraries(parentDir, inputFileContent, srcFiles, cb);
				});
				return;
			}
		}

		cb(updatedFileContent);
	});
}

module.exports = addLibraries;