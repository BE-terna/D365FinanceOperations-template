Add all AX modules under the /PackagesLocalDirectory folder.

Example tree structure:
- PackagesLocalDirectory
   - MyMainPackage
     - Descriptor
       - MyFirstModel.xml
       - MyOtherModel.xml
   
      - MyFirstModel
        - AxClass
          - MyClass.xml
        - AxTable
          - MyMainTable.xml
     
      - MyOtherModel
        - AxForm
          - MyOtherForm.xml

  - MyOtherPackage
    - Descriptor
      - MyTestModel.xml
    - MyTestModel
      - AxClass
        - MyTestClass.xml
- Projects
  - MyProject
    - MyProject.rnrproj

Please see https://ax.help.dynamics.com for more details.