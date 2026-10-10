/*
  GadgetHub - database setup (schema + data)

  Creates the four SQL Server databases the services expect, with their tables
  and the product, inventory and account data. Safe to re-run: existing databases, tables and rows are skipped.

  Run it with SQL Server Management Studio, or from a terminal:
      sqlcmd -S localhost\SQLEXPRESS -E -i database\setup.sql

  Databases
      GadgetHubDB      OrderAPI + QuotationAPI
      TechWorldDB      TechWorldAPI
      ElectroComDB     ElectroComAPI
      GadgetCentralDB  GadgetCentralAPI

  Customers and orders are not included. Account passwords are demo values stored
  as plain text, because the application currently compares them that way (see README).
*/

SET NOCOUNT ON;
GO

/* ===================================================================
   GadgetHubDB
   =================================================================== */
IF DB_ID(N'GadgetHubDB') IS NULL CREATE DATABASE [GadgetHubDB];
GO
USE [GadgetHubDB];
GO

IF OBJECT_ID(N'dbo.Customers', N'U') IS NULL
CREATE TABLE dbo.Customers (
    CustomerId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    CustomerName NVARCHAR(200) NOT NULL,
    Email        NVARCHAR(255) NULL,
    Phone        NVARCHAR(20)  NULL,
    Password     NVARCHAR(255) NOT NULL,
    CreatedDate  DATETIME2     NOT NULL CONSTRAINT DF_Customers_CreatedDate DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID(N'dbo.Products', N'U') IS NULL
CREATE TABLE dbo.Products (
    ProductId   INT NOT NULL CONSTRAINT PK_Products PRIMARY KEY,
    ProductName NVARCHAR(200)  NOT NULL,
    BasePrice   DECIMAL(18,2)  NOT NULL,
    Category    NVARCHAR(100)  NULL
);
GO

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
CREATE TABLE dbo.Orders (
    OrderId             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId          INT            NOT NULL,
    CustomerName        NVARCHAR(200)  NOT NULL,
    OrderDate           DATETIME2      NOT NULL,
    TotalAmount         DECIMAL(18,2)  NOT NULL,
    SelectedDistributor NVARCHAR(100)  NULL,
    DeliveryDays        INT            NULL,
    IsSplitOrder        BIT            NOT NULL CONSTRAINT DF_Orders_IsSplitOrder DEFAULT 0,
    Status              NVARCHAR(50)   NULL,
    CreatedAt           DATETIME2      NOT NULL CONSTRAINT DF_Orders_CreatedAt DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NULL
CREATE TABLE dbo.OrderItems (
    OrderItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderId     INT            NOT NULL,
    ProductId   INT            NOT NULL,
    ProductName NVARCHAR(200)  NOT NULL,
    Quantity    INT            NOT NULL,
    UnitPrice   DECIMAL(18,2)  NOT NULL,
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId)
        REFERENCES dbo.Orders (OrderId) ON DELETE CASCADE
);
GO

/* Shared by OrderAPI and QuotationAPI (both map an entity to this table) */
IF OBJECT_ID(N'dbo.Quotations', N'U') IS NULL
CREATE TABLE dbo.Quotations (
    QuotationId             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Quotations PRIMARY KEY,
    OrderId                 INT            NOT NULL,
    DistributorName         NVARCHAR(100)  NOT NULL,
    TotalPrice              DECIMAL(18,2)  NOT NULL,
    DeliveryDays            INT            NOT NULL,
    CanFulfillCompleteOrder BIT            NOT NULL CONSTRAINT DF_Quotations_CanFulfill DEFAULT 0,
    QuotationDate           DATETIME2      NOT NULL CONSTRAINT DF_Quotations_QuotationDate DEFAULT SYSUTCDATETIME(),
    Status                  NVARCHAR(50)   NULL,
    DistributorOrderId      NVARCHAR(50)   NULL,
    ConfirmedDate           DATETIME2      NULL,
    ConfirmedBy             NVARCHAR(200)  NULL
);
GO

IF OBJECT_ID(N'dbo.OrderDistributions', N'U') IS NULL
CREATE TABLE dbo.OrderDistributions (
    DistributionId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderDistributions PRIMARY KEY,
    OrderId               INT            NOT NULL,
    DistributorName       NVARCHAR(100)  NOT NULL,
    ProductId             INT            NOT NULL,
    ProductName           NVARCHAR(200)  NOT NULL,
    Quantity              INT            NOT NULL,
    UnitPrice             DECIMAL(18,2)  NOT NULL,
    TotalPrice            DECIMAL(18,2)  NOT NULL,
    DistributorOrderId    NVARCHAR(50)   NULL,
    Status                NVARCHAR(50)   NULL,
    EstimatedDeliveryDate DATETIME2      NULL,
    CreatedAt             DATETIME2      NOT NULL CONSTRAINT DF_OrderDistributions_CreatedAt DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID(N'dbo.DistributorStaff', N'U') IS NULL
CREATE TABLE dbo.DistributorStaff (
    StaffId         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DistributorStaff PRIMARY KEY,
    DistributorName NVARCHAR(100) NOT NULL,
    Username        NVARCHAR(100) NOT NULL,
    Password        NVARCHAR(255) NOT NULL,
    FullName        NVARCHAR(200) NOT NULL,
    Email           NVARCHAR(255) NOT NULL,
    CreatedDate     DATETIME2     NOT NULL CONSTRAINT DF_DistributorStaff_CreatedDate DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID(N'dbo.AdminUsers', N'U') IS NULL
CREATE TABLE dbo.AdminUsers (
    AdminId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AdminUsers PRIMARY KEY,
    Username    NVARCHAR(100) NOT NULL,
    Password    NVARCHAR(255) NOT NULL,
    FullName    NVARCHAR(200) NOT NULL,
    Email       NVARCHAR(255) NOT NULL,
    CreatedDate DATETIME2     NOT NULL CONSTRAINT DF_AdminUsers_CreatedDate DEFAULT SYSUTCDATETIME()
);
GO

/* Indexes (match the HasIndex calls in the DbContexts) */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Orders_CustomerId' AND object_id = OBJECT_ID(N'dbo.Orders'))
    CREATE INDEX IX_Orders_CustomerId ON dbo.Orders (CustomerId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Orders_OrderDate' AND object_id = OBJECT_ID(N'dbo.Orders'))
    CREATE INDEX IX_Orders_OrderDate ON dbo.Orders (OrderDate);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OrderItems_OrderId' AND object_id = OBJECT_ID(N'dbo.OrderItems'))
    CREATE INDEX IX_OrderItems_OrderId ON dbo.OrderItems (OrderId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Quotations_OrderId' AND object_id = OBJECT_ID(N'dbo.Quotations'))
    CREATE INDEX IX_Quotations_OrderId ON dbo.Quotations (OrderId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OrderDistributions_OrderId' AND object_id = OBJECT_ID(N'dbo.OrderDistributions'))
    CREATE INDEX IX_OrderDistributions_OrderId ON dbo.OrderDistributions (OrderId);
GO


/* ---- Data ---- */

IF NOT EXISTS (SELECT 1 FROM dbo.Products)
BEGIN
    INSERT INTO dbo.Products (ProductId, ProductName, BasePrice, Category) VALUES
        (1, N'Wireless Earbuds Pro', CAST(23997.00 AS Decimal(18, 2)), N'Audio'),
        (2, N'Noise Cancelling Headphones', CAST(44997.00 AS Decimal(18, 2)), N'Audio'),
        (3, N'Bluetooth Speaker Mini', CAST(11997.00 AS Decimal(18, 2)), N'Audio'),
        (4, N'Studio Monitor Headphones', CAST(59997.00 AS Decimal(18, 2)), N'Audio'),
        (5, N'Portable Bluetooth Speaker', CAST(26997.00 AS Decimal(18, 2)), N'Audio'),
        (6, N'Gaming Headset RGB', CAST(35997.00 AS Decimal(18, 2)), N'Audio'),
        (7, N'True Wireless Earbuds', CAST(17997.00 AS Decimal(18, 2)), N'Audio'),
        (8, N'Soundbar 2.1 Channel', CAST(53997.00 AS Decimal(18, 2)), N'Audio'),
        (9, N'Wireless Over-Ear Headphones', CAST(38997.00 AS Decimal(18, 2)), N'Audio'),
        (10, N'Compact Bluetooth Speaker', CAST(14997.00 AS Decimal(18, 2)), N'Audio'),
        (11, N'Sports Wireless Earbuds', CAST(20997.00 AS Decimal(18, 2)), N'Audio'),
        (12, N'Premium Noise Cancelling Headphones', CAST(89997.00 AS Decimal(18, 2)), N'Audio'),
        (13, N'Portable PA Speaker', CAST(47997.00 AS Decimal(18, 2)), N'Audio'),
        (14, N'USB Condenser Microphone', CAST(26997.00 AS Decimal(18, 2)), N'Audio'),
        (15, N'Wireless Karaoke Microphone', CAST(13797.00 AS Decimal(18, 2)), N'Audio'),
        (16, N'Hi-Fi Stereo Headphones', CAST(29997.00 AS Decimal(18, 2)), N'Audio'),
        (17, N'Waterproof Bluetooth Speaker', CAST(23997.00 AS Decimal(18, 2)), N'Audio'),
        (18, N'DJ Headphones Professional', CAST(74997.00 AS Decimal(18, 2)), N'Audio'),
        (19, N'Portable CD Player Bluetooth', CAST(20997.00 AS Decimal(18, 2)), N'Audio'),
        (20, N'Wireless TV Headphones', CAST(32997.00 AS Decimal(18, 2)), N'Audio'),
        (21, N'Bone Conduction Headphones', CAST(41997.00 AS Decimal(18, 2)), N'Audio'),
        (22, N'Party Speaker with Lights', CAST(56997.00 AS Decimal(18, 2)), N'Audio'),
        (23, N'In-Ear Monitor Earbuds', CAST(35997.00 AS Decimal(18, 2)), N'Audio'),
        (24, N'Vintage Bluetooth Speaker', CAST(29997.00 AS Decimal(18, 2)), N'Audio'),
        (25, N'Gaming Earbuds Low Latency', CAST(23997.00 AS Decimal(18, 2)), N'Audio'),
        (26, N'Wireless Headphones for Kids', CAST(11997.00 AS Decimal(18, 2)), N'Audio'),
        (27, N'Outdoor Rugged Speaker', CAST(38997.00 AS Decimal(18, 2)), N'Audio'),
        (28, N'Audiophile Wired Headphones', CAST(59997.00 AS Decimal(18, 2)), N'Audio'),
        (29, N'Mini Clip Speaker', CAST(8997.00 AS Decimal(18, 2)), N'Audio'),
        (30, N'Smart Speaker Voice Assistant', CAST(44997.00 AS Decimal(18, 2)), N'Audio'),
        (31, N'Smart Watch Fitness Tracker', CAST(59997.00 AS Decimal(18, 2)), N'Wearables'),
        (32, N'Fitness Band Heart Rate', CAST(14997.00 AS Decimal(18, 2)), N'Wearables'),
        (33, N'Smart Watch Pro GPS', CAST(89997.00 AS Decimal(18, 2)), N'Wearables'),
        (34, N'Kids Smart Watch GPS', CAST(23997.00 AS Decimal(18, 2)), N'Wearables'),
        (35, N'Fitness Tracker Waterproof', CAST(38997.00 AS Decimal(18, 2)), N'Wearables'),
        (36, N'Smart Watch Touchscreen', CAST(47997.00 AS Decimal(18, 2)), N'Wearables'),
        (37, N'Running Watch GPS', CAST(53997.00 AS Decimal(18, 2)), N'Wearables'),
        (38, N'Health Monitoring Smart Band', CAST(26997.00 AS Decimal(18, 2)), N'Wearables'),
        (39, N'Luxury Smart Watch', CAST(119997.00 AS Decimal(18, 2)), N'Wearables'),
        (40, N'Sports Smart Watch', CAST(44997.00 AS Decimal(18, 2)), N'Wearables'),
        (41, N'Sleep Tracker Band', CAST(20997.00 AS Decimal(18, 2)), N'Wearables'),
        (42, N'Smart Watch Women Edition', CAST(68997.00 AS Decimal(18, 2)), N'Wearables'),
        (43, N'Outdoor Adventure Watch', CAST(74997.00 AS Decimal(18, 2)), N'Wearables'),
        (44, N'Smart Ring Fitness', CAST(59997.00 AS Decimal(18, 2)), N'Wearables'),
        (45, N'Blood Pressure Monitor Watch', CAST(47997.00 AS Decimal(18, 2)), N'Wearables'),
        (46, N'Smart Watch for Seniors', CAST(35997.00 AS Decimal(18, 2)), N'Wearables'),
        (47, N'Diving Smart Watch', CAST(89997.00 AS Decimal(18, 2)), N'Wearables'),
        (48, N'Fashion Smart Watch', CAST(56997.00 AS Decimal(18, 2)), N'Wearables'),
        (49, N'ECG Monitor Smart Watch', CAST(83997.00 AS Decimal(18, 2)), N'Wearables'),
        (50, N'Budget Fitness Tracker', CAST(11997.00 AS Decimal(18, 2)), N'Wearables'),
        (51, N'Premium Health Watch', CAST(134997.00 AS Decimal(18, 2)), N'Wearables'),
        (52, N'Smart Glasses AR', CAST(179997.00 AS Decimal(18, 2)), N'Wearables'),
        (53, N'Posture Corrector Smart', CAST(23997.00 AS Decimal(18, 2)), N'Wearables'),
        (54, N'Smart Jewelry Bracelet', CAST(38997.00 AS Decimal(18, 2)), N'Wearables'),
        (55, N'Cycling Computer Watch', CAST(59997.00 AS Decimal(18, 2)), N'Wearables'),
        (56, N'Golf GPS Watch', CAST(74997.00 AS Decimal(18, 2)), N'Wearables'),
        (57, N'Meditation Band Biofeedback', CAST(44997.00 AS Decimal(18, 2)), N'Wearables'),
        (58, N'Smart Clip Fitness Tracker', CAST(14997.00 AS Decimal(18, 2)), N'Wearables'),
        (59, N'Hybrid Smart Watch', CAST(53997.00 AS Decimal(18, 2)), N'Wearables'),
        (60, N'Temperature Monitoring Band', CAST(26997.00 AS Decimal(18, 2)), N'Wearables'),
        (61, N'Portable Charger 10000mAh', CAST(11997.00 AS Decimal(18, 2)), N'Accessories'),
        (62, N'Wireless Charging Pad', CAST(8997.00 AS Decimal(18, 2)), N'Accessories'),
        (63, N'USB-C Hub Multiport', CAST(14997.00 AS Decimal(18, 2)), N'Accessories'),
        (64, N'Power Bank 20000mAh', CAST(17997.00 AS Decimal(18, 2)), N'Accessories'),
        (65, N'Fast Wireless Charger', CAST(11997.00 AS Decimal(18, 2)), N'Accessories'),
        (66, N'Cable Organizer Kit', CAST(5997.00 AS Decimal(18, 2)), N'Accessories'),
        (67, N'Phone Stand Adjustable', CAST(7497.00 AS Decimal(18, 2)), N'Accessories'),
        (68, N'Laptop Stand Aluminum', CAST(13497.00 AS Decimal(18, 2)), N'Accessories'),
        (69, N'Screen Protector Kit', CAST(4497.00 AS Decimal(18, 2)), N'Accessories'),
        (70, N'Phone Case Protective', CAST(8997.00 AS Decimal(18, 2)), N'Accessories'),
        (71, N'Car Mount Phone Holder', CAST(5997.00 AS Decimal(18, 2)), N'Accessories'),
        (72, N'Selfie Stick Bluetooth', CAST(7497.00 AS Decimal(18, 2)), N'Accessories'),
        (73, N'Ring Light for Video', CAST(14997.00 AS Decimal(18, 2)), N'Accessories'),
        (74, N'Webcam HD 1080p', CAST(23997.00 AS Decimal(18, 2)), N'Accessories'),
        (75, N'USB Flash Drive 128GB', CAST(8997.00 AS Decimal(18, 2)), N'Accessories'),
        (76, N'SD Card 256GB', CAST(14997.00 AS Decimal(18, 2)), N'Accessories'),
        (77, N'Cable Management Box', CAST(7497.00 AS Decimal(18, 2)), N'Accessories'),
        (78, N'Wireless Mouse Ergonomic', CAST(10497.00 AS Decimal(18, 2)), N'Accessories'),
        (79, N'Mechanical Keyboard RGB', CAST(26997.00 AS Decimal(18, 2)), N'Accessories'),
        (80, N'Monitor Arm Dual', CAST(23997.00 AS Decimal(18, 2)), N'Accessories'),
        (81, N'Laptop Cooling Pad', CAST(11997.00 AS Decimal(18, 2)), N'Accessories'),
        (82, N'Drawing Tablet Graphics', CAST(44997.00 AS Decimal(18, 2)), N'Accessories'),
        (83, N'Stylus Pen Precision', CAST(11997.00 AS Decimal(18, 2)), N'Accessories'),
        (84, N'VR Headset Stand', CAST(8997.00 AS Decimal(18, 2)), N'Accessories'),
        (85, N'Gaming Mouse Pad XXL', CAST(7497.00 AS Decimal(18, 2)), N'Accessories'),
        (86, N'Cable Tester Multimeter', CAST(10497.00 AS Decimal(18, 2)), N'Accessories'),
        (87, N'Phone Grip Ring Holder', CAST(2997.00 AS Decimal(18, 2)), N'Accessories'),
        (88, N'Laptop Sleeve 15 inch', CAST(8997.00 AS Decimal(18, 2)), N'Accessories'),
        (89, N'Desk Organizer Tech', CAST(10497.00 AS Decimal(18, 2)), N'Accessories'),
        (90, N'Blue Light Blocking Glasses', CAST(8997.00 AS Decimal(18, 2)), N'Accessories'),
        (91, N'Smart Light Bulb RGB', CAST(8997.00 AS Decimal(18, 2)), N'Smart Home'),
        (92, N'Smart Plug WiFi', CAST(5997.00 AS Decimal(18, 2)), N'Smart Home'),
        (93, N'Video Doorbell Camera', CAST(44997.00 AS Decimal(18, 2)), N'Smart Home'),
        (94, N'Smart Thermostat', CAST(53997.00 AS Decimal(18, 2)), N'Smart Home'),
        (95, N'Security Camera Indoor', CAST(14997.00 AS Decimal(18, 2)), N'Smart Home'),
        (96, N'Smart Lock Keyless', CAST(59997.00 AS Decimal(18, 2)), N'Smart Home'),
        (97, N'Motion Sensor Smart', CAST(10497.00 AS Decimal(18, 2)), N'Smart Home'),
        (98, N'Smart LED Strip 16ft', CAST(11997.00 AS Decimal(18, 2)), N'Smart Home'),
        (99, N'WiFi Range Extender', CAST(14997.00 AS Decimal(18, 2)), N'Smart Home'),
        (100, N'Smart Smoke Detector', CAST(26997.00 AS Decimal(18, 2)), N'Smart Home'),
        (101, N'Robot Vacuum Cleaner', CAST(89997.00 AS Decimal(18, 2)), N'Smart Home'),
        (102, N'Smart Air Purifier', CAST(59997.00 AS Decimal(18, 2)), N'Smart Home'),
        (103, N'Smart Garage Door Opener', CAST(38997.00 AS Decimal(18, 2)), N'Smart Home'),
        (104, N'Video Baby Monitor', CAST(35997.00 AS Decimal(18, 2)), N'Smart Home'),
        (105, N'Smart Blinds Controller', CAST(44997.00 AS Decimal(18, 2)), N'Smart Home'),
        (106, N'Water Leak Detector Smart', CAST(11997.00 AS Decimal(18, 2)), N'Smart Home'),
        (107, N'Smart Power Strip', CAST(13497.00 AS Decimal(18, 2)), N'Smart Home'),
        (108, N'Outdoor Security Camera', CAST(29997.00 AS Decimal(18, 2)), N'Smart Home'),
        (109, N'Smart Doorbell Chime', CAST(8997.00 AS Decimal(18, 2)), N'Smart Home'),
        (110, N'Humidity Monitor Smart', CAST(10497.00 AS Decimal(18, 2)), N'Smart Home'),
        (111, N'Smart Fan Controller', CAST(14997.00 AS Decimal(18, 2)), N'Smart Home'),
        (112, N'Pet Camera with Treat', CAST(38997.00 AS Decimal(18, 2)), N'Smart Home'),
        (113, N'Smart Water Valve', CAST(26997.00 AS Decimal(18, 2)), N'Smart Home'),
        (114, N'WiFi Router Mesh System', CAST(59997.00 AS Decimal(18, 2)), N'Smart Home'),
        (115, N'Smart Mirror Display', CAST(119997.00 AS Decimal(18, 2)), N'Smart Home'),
        (116, N'Door Window Sensor Kit', CAST(13497.00 AS Decimal(18, 2)), N'Smart Home'),
        (117, N'Smart Sprinkler Controller', CAST(44997.00 AS Decimal(18, 2)), N'Smart Home'),
        (118, N'Air Quality Monitor', CAST(23997.00 AS Decimal(18, 2)), N'Smart Home'),
        (119, N'Smart Button Controller', CAST(7497.00 AS Decimal(18, 2)), N'Smart Home'),
        (120, N'Universal Remote Control', CAST(17997.00 AS Decimal(18, 2)), N'Smart Home'),
        (121, N'External SSD 1TB', CAST(38997.00 AS Decimal(18, 2)), N'Computing'),
        (122, N'USB Hub 7-Port', CAST(10497.00 AS Decimal(18, 2)), N'Computing'),
        (123, N'Portable Monitor 15.6 inch', CAST(59997.00 AS Decimal(18, 2)), N'Computing'),
        (124, N'Docking Station USB-C', CAST(44997.00 AS Decimal(18, 2)), N'Computing'),
        (125, N'Wireless Keyboard Mouse Combo', CAST(17997.00 AS Decimal(18, 2)), N'Computing'),
        (126, N'RAM 16GB DDR4', CAST(23997.00 AS Decimal(18, 2)), N'Computing'),
        (127, N'Graphics Card GTX', CAST(149997.00 AS Decimal(18, 2)), N'Computing'),
        (128, N'CPU Cooler RGB', CAST(26997.00 AS Decimal(18, 2)), N'Computing'),
        (129, N'Gaming Chair Ergonomic', CAST(74997.00 AS Decimal(18, 2)), N'Computing'),
        (130, N'Desk Mat Extended', CAST(8997.00 AS Decimal(18, 2)), N'Computing'),
        (131, N'Monitor 27 inch 4K', CAST(119997.00 AS Decimal(18, 2)), N'Computing'),
        (132, N'NVMe SSD 500GB', CAST(26997.00 AS Decimal(18, 2)), N'Computing'),
        (133, N'Thunderbolt Cable 2m', CAST(11997.00 AS Decimal(18, 2)), N'Computing'),
        (134, N'KVM Switch 2 Port', CAST(14997.00 AS Decimal(18, 2)), N'Computing'),
        (135, N'Headphone Stand RGB', CAST(10497.00 AS Decimal(18, 2)), N'Computing'),
        (136, N'Cable Sleeve Kit', CAST(5997.00 AS Decimal(18, 2)), N'Computing'),
        (137, N'Vertical GPU Mount', CAST(13497.00 AS Decimal(18, 2)), N'Computing'),
        (138, N'PC Case ATX RGB', CAST(29997.00 AS Decimal(18, 2)), N'Computing'),
        (139, N'Power Supply 750W', CAST(38997.00 AS Decimal(18, 2)), N'Computing'),
        (140, N'Motherboard B550', CAST(53997.00 AS Decimal(18, 2)), N'Computing'),
        (141, N'WiFi Card PCIe', CAST(13497.00 AS Decimal(18, 2)), N'Computing'),
        (142, N'Sound Card USB External', CAST(17997.00 AS Decimal(18, 2)), N'Computing'),
        (143, N'Capture Card HDMI', CAST(44997.00 AS Decimal(18, 2)), N'Computing'),
        (144, N'Streaming Deck Control', CAST(38997.00 AS Decimal(18, 2)), N'Computing'),
        (145, N'Desk Lamp LED Monitor', CAST(14997.00 AS Decimal(18, 2)), N'Computing'),
        (146, N'Ergonomic Mouse Vertical', CAST(11997.00 AS Decimal(18, 2)), N'Computing'),
        (147, N'Wrist Rest Keyboard', CAST(7497.00 AS Decimal(18, 2)), N'Computing'),
        (148, N'Monitor Privacy Screen', CAST(14997.00 AS Decimal(18, 2)), N'Computing'),
        (149, N'Cable Clips 50 Pack', CAST(3897.00 AS Decimal(18, 2)), N'Computing'),
        (150, N'Anti-Static Wrist Strap', CAST(2997.00 AS Decimal(18, 2)), N'Computing');
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.AdminUsers)
BEGIN
    SET IDENTITY_INSERT dbo.AdminUsers ON;
    INSERT INTO dbo.AdminUsers (AdminId, Username, Password, FullName, Email, CreatedDate) VALUES
        (1, N'admin', N'admin123', N'System Administrator', N'admin@gadgethub.com', CAST(N'2026-02-15T17:54:43.297' AS DateTime));
    SET IDENTITY_INSERT dbo.AdminUsers OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DistributorStaff)
BEGIN
    SET IDENTITY_INSERT dbo.DistributorStaff ON;
    INSERT INTO dbo.DistributorStaff (StaffId, DistributorName, Username, Password, FullName, Email, CreatedDate) VALUES
        (1, N'TechWorld', N'techworld_staff', N'tech123', N'TechWorld Manager', N'manager@techworld.com', CAST(N'2026-02-15T17:54:43.283' AS DateTime)),
        (2, N'ElectroCom', N'electrocom_staff', N'electro123', N'ElectroCom Manager', N'manager@electrocom.com', CAST(N'2026-02-15T17:54:43.283' AS DateTime)),
        (3, N'Gadget Central', N'gadgetcentral_staff', N'gadget123', N'Gadget Central Manager', N'manager@gadgetcentral.com', CAST(N'2026-02-15T17:54:43.283' AS DateTime)),
        (4, N'TechWorld', N'techworld', N'tech123', N'TechWorld Manager', N'manager@techworld.com', CAST(N'2026-02-15T18:11:01.690' AS DateTime)),
        (5, N'ElectroCom', N'electrocom', N'electro123', N'ElectroCom Manager', N'manager@electrocom.com', CAST(N'2026-02-15T18:11:01.690' AS DateTime)),
        (6, N'Gadget Central', N'gadgetcentral', N'gadget123', N'Gadget Central Manager', N'manager@gadgetcentral.com', CAST(N'2026-02-15T18:11:01.690' AS DateTime));
    SET IDENTITY_INSERT dbo.DistributorStaff OFF;
END
GO

/* ===================================================================
   TechWorldDB
   =================================================================== */
IF DB_ID(N'TechWorldDB') IS NULL CREATE DATABASE [TechWorldDB];
GO
USE [TechWorldDB];
GO

IF OBJECT_ID(N'dbo.Inventory', N'U') IS NULL
CREATE TABLE dbo.Inventory (
    InventoryId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Inventory PRIMARY KEY,
    ProductId     INT            NOT NULL,
    ProductName   NVARCHAR(200)  NOT NULL,
    UnitPrice     DECIMAL(18,2)  NOT NULL,
    StockQuantity INT            NOT NULL,
    ReorderLevel  INT            NOT NULL CONSTRAINT DF_Inventory_ReorderLevel DEFAULT 10,
    LastUpdated   DATETIME2      NOT NULL CONSTRAINT DF_Inventory_LastUpdated DEFAULT SYSUTCDATETIME()
);
GO


IF NOT EXISTS (SELECT 1 FROM dbo.Inventory)
BEGIN
    SET IDENTITY_INSERT dbo.Inventory ON;
    INSERT INTO dbo.Inventory (InventoryId, ProductId, ProductName, UnitPrice, StockQuantity, ReorderLevel, LastUpdated) VALUES
        (166, 1, N'Wireless Earbuds Pro', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (167, 2, N'Noise Cancelling Headphones', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (168, 3, N'Bluetooth Speaker Mini', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (169, 4, N'Studio Monitor Headphones', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (170, 5, N'Portable Bluetooth Speaker', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (171, 6, N'Gaming Headset RGB', CAST(37796.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (172, 7, N'True Wireless Earbuds', CAST(18896.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (173, 8, N'Soundbar 2.1 Channel', CAST(56696.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (174, 9, N'Wireless Over-Ear Headphones', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (175, 10, N'Compact Bluetooth Speaker', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (176, 11, N'Sports Wireless Earbuds', CAST(22046.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (177, 12, N'Premium Noise Cancelling Headphones', CAST(94496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (178, 13, N'Portable PA Speaker', CAST(50396.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (179, 14, N'USB Condenser Microphone', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (180, 15, N'Wireless Karaoke Microphone', CAST(14486.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (181, 16, N'Hi-Fi Stereo Headphones', CAST(31496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (182, 17, N'Waterproof Bluetooth Speaker', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (183, 18, N'DJ Headphones Professional', CAST(78746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (184, 19, N'Portable CD Player Bluetooth', CAST(22046.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (185, 20, N'Wireless TV Headphones', CAST(34646.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (186, 21, N'Bone Conduction Headphones', CAST(44096.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (187, 22, N'Party Speaker with Lights', CAST(59846.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (188, 23, N'In-Ear Monitor Earbuds', CAST(37796.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (189, 24, N'Vintage Bluetooth Speaker', CAST(31496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (190, 25, N'Gaming Earbuds Low Latency', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (191, 26, N'Wireless Headphones for Kids', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (192, 27, N'Outdoor Rugged Speaker', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (193, 28, N'Audiophile Wired Headphones', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (194, 29, N'Mini Clip Speaker', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (195, 30, N'Smart Speaker Voice Assistant', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (196, 31, N'Smart Watch Fitness Tracker', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (197, 32, N'Fitness Band Heart Rate', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (198, 33, N'Smart Watch Pro GPS', CAST(94496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (199, 34, N'Kids Smart Watch GPS', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (200, 35, N'Fitness Tracker Waterproof', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (201, 36, N'Smart Watch Touchscreen', CAST(50396.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (202, 37, N'Running Watch GPS', CAST(56696.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (203, 38, N'Health Monitoring Smart Band', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (204, 39, N'Luxury Smart Watch', CAST(125996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (205, 40, N'Sports Smart Watch', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (206, 41, N'Sleep Tracker Band', CAST(22046.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (207, 42, N'Smart Watch Women Edition', CAST(72446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (208, 43, N'Outdoor Adventure Watch', CAST(78746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (209, 44, N'Smart Ring Fitness', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (210, 45, N'Blood Pressure Monitor Watch', CAST(50396.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (211, 46, N'Smart Watch for Seniors', CAST(37796.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (212, 47, N'Diving Smart Watch', CAST(94496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (213, 48, N'Fashion Smart Watch', CAST(59846.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (214, 49, N'ECG Monitor Smart Watch', CAST(88196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (215, 50, N'Budget Fitness Tracker', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (216, 51, N'Premium Health Watch', CAST(141746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (217, 52, N'Smart Glasses AR', CAST(188996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (218, 53, N'Posture Corrector Smart', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (219, 54, N'Smart Jewelry Bracelet', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (220, 55, N'Cycling Computer Watch', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (221, 56, N'Golf GPS Watch', CAST(78746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (222, 57, N'Meditation Band Biofeedback', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (223, 58, N'Smart Clip Fitness Tracker', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (224, 59, N'Hybrid Smart Watch', CAST(56696.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (225, 60, N'Temperature Monitoring Band', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (226, 61, N'Portable Charger 10000mAh', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (227, 62, N'Wireless Charging Pad', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (228, 63, N'USB-C Hub Multiport', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (229, 64, N'Power Bank 20000mAh', CAST(18896.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (230, 65, N'Fast Wireless Charger', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (231, 66, N'Cable Organizer Kit', CAST(6296.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (232, 67, N'Phone Stand Adjustable', CAST(7871.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (233, 68, N'Laptop Stand Aluminum', CAST(14171.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (234, 69, N'Screen Protector Kit', CAST(4721.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (235, 70, N'Phone Case Protective', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (236, 71, N'Car Mount Phone Holder', CAST(6296.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (237, 72, N'Selfie Stick Bluetooth', CAST(7871.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (238, 73, N'Ring Light for Video', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (239, 74, N'Webcam HD 1080p', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (240, 75, N'USB Flash Drive 128GB', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (241, 76, N'SD Card 256GB', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (242, 77, N'Cable Management Box', CAST(7871.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (243, 78, N'Wireless Mouse Ergonomic', CAST(11021.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (244, 79, N'Mechanical Keyboard RGB', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (245, 80, N'Monitor Arm Dual', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (246, 81, N'Laptop Cooling Pad', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (247, 82, N'Drawing Tablet Graphics', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (248, 83, N'Stylus Pen Precision', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (249, 84, N'VR Headset Stand', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (250, 85, N'Gaming Mouse Pad XXL', CAST(7871.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (251, 86, N'Cable Tester Multimeter', CAST(11021.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (252, 87, N'Phone Grip Ring Holder', CAST(3146.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (253, 88, N'Laptop Sleeve 15 inch', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (254, 89, N'Desk Organizer Tech', CAST(11021.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (255, 90, N'Blue Light Blocking Glasses', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (256, 91, N'Smart Light Bulb RGB', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (257, 92, N'Smart Plug WiFi', CAST(6296.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (258, 93, N'Video Doorbell Camera', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (259, 94, N'Smart Thermostat', CAST(56696.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (260, 95, N'Security Camera Indoor', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (261, 96, N'Smart Lock Keyless', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (262, 97, N'Motion Sensor Smart', CAST(11021.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (263, 98, N'Smart LED Strip 16ft', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (264, 99, N'WiFi Range Extender', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (265, 100, N'Smart Smoke Detector', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (266, 101, N'Robot Vacuum Cleaner', CAST(94496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (267, 102, N'Smart Air Purifier', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (268, 103, N'Smart Garage Door Opener', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (269, 104, N'Video Baby Monitor', CAST(37796.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (270, 105, N'Smart Blinds Controller', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (271, 106, N'Water Leak Detector Smart', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (272, 107, N'Smart Power Strip', CAST(14171.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (273, 108, N'Outdoor Security Camera', CAST(31496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (274, 109, N'Smart Doorbell Chime', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (275, 110, N'Humidity Monitor Smart', CAST(11021.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (276, 111, N'Smart Fan Controller', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (277, 112, N'Pet Camera with Treat', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (278, 113, N'Smart Water Valve', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (279, 114, N'WiFi Router Mesh System', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (280, 115, N'Smart Mirror Display', CAST(125996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (281, 116, N'Door Window Sensor Kit', CAST(14171.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (282, 117, N'Smart Sprinkler Controller', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (283, 118, N'Air Quality Monitor', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (284, 119, N'Smart Button Controller', CAST(7871.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (285, 120, N'Universal Remote Control', CAST(18896.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (286, 121, N'External SSD 1TB', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (287, 122, N'USB Hub 7-Port', CAST(11021.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (288, 123, N'Portable Monitor 15.6 inch', CAST(62996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (289, 124, N'Docking Station USB-C', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (290, 125, N'Wireless Keyboard Mouse Combo', CAST(18896.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (291, 126, N'RAM 16GB DDR4', CAST(25196.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (292, 127, N'Graphics Card GTX', CAST(157496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (293, 128, N'CPU Cooler RGB', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (294, 129, N'Gaming Chair Ergonomic', CAST(78746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (295, 130, N'Desk Mat Extended', CAST(9446.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (296, 131, N'Monitor 27 inch 4K', CAST(125996.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (297, 132, N'NVMe SSD 500GB', CAST(28346.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (298, 133, N'Thunderbolt Cable 2m', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (299, 134, N'KVM Switch 2 Port', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (300, 135, N'Headphone Stand RGB', CAST(11021.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (301, 136, N'Cable Sleeve Kit', CAST(6296.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (302, 137, N'Vertical GPU Mount', CAST(14171.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (303, 138, N'PC Case ATX RGB', CAST(31496.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (304, 139, N'Power Supply 750W', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (305, 140, N'Motherboard B550', CAST(56696.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (306, 141, N'WiFi Card PCIe', CAST(14171.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (307, 142, N'Sound Card USB External', CAST(18896.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (308, 143, N'Capture Card HDMI', CAST(47246.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (309, 144, N'Streaming Deck Control', CAST(40946.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (310, 145, N'Desk Lamp LED Monitor', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (311, 146, N'Ergonomic Mouse Vertical', CAST(12596.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (312, 147, N'Wrist Rest Keyboard', CAST(7871.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (313, 148, N'Monitor Privacy Screen', CAST(15746.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (314, 149, N'Cable Clips 50 Pack', CAST(4091.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime)),
        (315, 150, N'Anti-Static Wrist Strap', CAST(3146.85 AS Decimal(18, 2)), 50, 10, CAST(N'2026-02-17T03:57:11.687' AS DateTime));
    SET IDENTITY_INSERT dbo.Inventory OFF;
END
GO

/* ===================================================================
   ElectroComDB
   =================================================================== */
IF DB_ID(N'ElectroComDB') IS NULL CREATE DATABASE [ElectroComDB];
GO
USE [ElectroComDB];
GO

IF OBJECT_ID(N'dbo.Inventory', N'U') IS NULL
CREATE TABLE dbo.Inventory (
    InventoryId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Inventory PRIMARY KEY,
    ProductId     INT            NOT NULL,
    ProductName   NVARCHAR(200)  NOT NULL,
    UnitPrice     DECIMAL(18,2)  NOT NULL,
    StockQuantity INT            NOT NULL,
    ReorderLevel  INT            NOT NULL CONSTRAINT DF_Inventory_ReorderLevel DEFAULT 10,
    LastUpdated   DATETIME2      NOT NULL CONSTRAINT DF_Inventory_LastUpdated DEFAULT SYSUTCDATETIME()
);
GO


IF NOT EXISTS (SELECT 1 FROM dbo.Inventory)
BEGIN
    SET IDENTITY_INSERT dbo.Inventory ON;
    INSERT INTO dbo.Inventory (InventoryId, ProductId, ProductName, UnitPrice, StockQuantity, ReorderLevel, LastUpdated) VALUES
        (166, 1, N'Wireless Earbuds Pro', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (167, 2, N'Noise Cancelling Headphones', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (168, 3, N'Bluetooth Speaker Mini', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (169, 4, N'Studio Monitor Headphones', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (170, 5, N'Portable Bluetooth Speaker', CAST(27806.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (171, 6, N'Gaming Headset RGB', CAST(37076.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (172, 7, N'True Wireless Earbuds', CAST(18536.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (173, 8, N'Soundbar 2.1 Channel', CAST(55616.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (174, 9, N'Wireless Over-Ear Headphones', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (175, 10, N'Compact Bluetooth Speaker', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (176, 11, N'Sports Wireless Earbuds', CAST(21626.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (177, 12, N'Premium Noise Cancelling Headphones', CAST(92696.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (178, 13, N'Portable PA Speaker', CAST(49436.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (179, 14, N'USB Condenser Microphone', CAST(27806.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (180, 15, N'Wireless Karaoke Microphone', CAST(14210.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (181, 16, N'Hi-Fi Stereo Headphones', CAST(30896.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (182, 17, N'Waterproof Bluetooth Speaker', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (183, 18, N'DJ Headphones Professional', CAST(77246.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (184, 19, N'Portable CD Player Bluetooth', CAST(21626.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (185, 20, N'Wireless TV Headphones', CAST(33986.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (186, 21, N'Bone Conduction Headphones', CAST(43256.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (187, 22, N'Party Speaker with Lights', CAST(58706.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (188, 23, N'In-Ear Monitor Earbuds', CAST(37076.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (189, 24, N'Vintage Bluetooth Speaker', CAST(30896.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (190, 25, N'Gaming Earbuds Low Latency', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (191, 26, N'Wireless Headphones for Kids', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (192, 27, N'Outdoor Rugged Speaker', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (193, 28, N'Audiophile Wired Headphones', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (194, 29, N'Mini Clip Speaker', CAST(9266.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (195, 30, N'Smart Speaker Voice Assistant', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (196, 31, N'Smart Watch Fitness Tracker', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (197, 32, N'Fitness Band Heart Rate', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (198, 33, N'Smart Watch Pro GPS', CAST(92696.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (199, 34, N'Kids Smart Watch GPS', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (200, 35, N'Fitness Tracker Waterproof', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (201, 36, N'Smart Watch Touchscreen', CAST(49436.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (202, 37, N'Running Watch GPS', CAST(55616.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (203, 38, N'Health Monitoring Smart Band', CAST(27806.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (204, 39, N'Luxury Smart Watch', CAST(123596.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (205, 40, N'Sports Smart Watch', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (206, 41, N'Sleep Tracker Band', CAST(21626.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (207, 42, N'Smart Watch Women Edition', CAST(71066.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (208, 43, N'Outdoor Adventure Watch', CAST(77246.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (209, 44, N'Smart Ring Fitness', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (210, 45, N'Blood Pressure Monitor Watch', CAST(49436.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (211, 46, N'Smart Watch for Seniors', CAST(37076.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (212, 47, N'Diving Smart Watch', CAST(92696.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (213, 48, N'Fashion Smart Watch', CAST(58706.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (214, 49, N'ECG Monitor Smart Watch', CAST(86516.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (215, 50, N'Budget Fitness Tracker', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (216, 51, N'Premium Health Watch', CAST(139046.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (217, 52, N'Smart Glasses AR', CAST(185396.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (218, 53, N'Posture Corrector Smart', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (219, 54, N'Smart Jewelry Bracelet', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (220, 55, N'Cycling Computer Watch', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (221, 56, N'Golf GPS Watch', CAST(77246.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (222, 57, N'Meditation Band Biofeedback', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (223, 58, N'Smart Clip Fitness Tracker', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (224, 59, N'Hybrid Smart Watch', CAST(55616.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (225, 60, N'Temperature Monitoring Band', CAST(27806.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (226, 61, N'Portable Charger 10000mAh', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (227, 62, N'Wireless Charging Pad', CAST(9266.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (228, 63, N'USB-C Hub Multiport', CAST(15446.91 AS Decimal(18, 2)), 79, 10, CAST(N'2026-02-17T04:35:01.613' AS DateTime)),
        (229, 64, N'Power Bank 20000mAh', CAST(18536.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (230, 65, N'Fast Wireless Charger', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (231, 66, N'Cable Organizer Kit', CAST(6176.91 AS Decimal(18, 2)), 70, 10, CAST(N'2026-02-19T22:53:58.363' AS DateTime)),
        (232, 67, N'Phone Stand Adjustable', CAST(7721.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (233, 68, N'Laptop Stand Aluminum', CAST(13901.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (234, 69, N'Screen Protector Kit', CAST(4631.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (235, 70, N'Phone Case Protective', CAST(9266.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (236, 71, N'Car Mount Phone Holder', CAST(6176.91 AS Decimal(18, 2)), 79, 10, CAST(N'2026-02-17T04:12:14.123' AS DateTime)),
        (237, 72, N'Selfie Stick Bluetooth', CAST(7721.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (238, 73, N'Ring Light for Video', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (239, 74, N'Webcam HD 1080p', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (240, 75, N'USB Flash Drive 128GB', CAST(9266.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (241, 76, N'SD Card 256GB', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (242, 77, N'Cable Management Box', CAST(7721.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (243, 78, N'Wireless Mouse Ergonomic', CAST(10811.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (244, 79, N'Mechanical Keyboard RGB', CAST(27806.91 AS Decimal(18, 2)), 79, 10, CAST(N'2026-02-17T09:59:23.733' AS DateTime)),
        (245, 80, N'Monitor Arm Dual', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (246, 81, N'Laptop Cooling Pad', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (247, 82, N'Drawing Tablet Graphics', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (248, 83, N'Stylus Pen Precision', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (249, 84, N'VR Headset Stand', CAST(9266.91 AS Decimal(18, 2)), 76, 10, CAST(N'2026-02-19T21:52:03.410' AS DateTime)),
        (250, 85, N'Gaming Mouse Pad XXL', CAST(7721.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (251, 86, N'Cable Tester Multimeter', CAST(10811.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (252, 87, N'Phone Grip Ring Holder', CAST(3086.91 AS Decimal(18, 2)), 79, 10, CAST(N'2026-02-17T09:59:23.740' AS DateTime)),
        (253, 88, N'Laptop Sleeve 15 inch', CAST(9266.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (254, 89, N'Desk Organizer Tech', CAST(10811.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (255, 90, N'Blue Light Blocking Glasses', CAST(9266.91 AS Decimal(18, 2)), 79, 10, CAST(N'2026-02-17T04:12:14.120' AS DateTime)),
        (256, 91, N'Smart Light Bulb RGB', CAST(9266.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (257, 92, N'Smart Plug WiFi', CAST(6176.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (258, 93, N'Video Doorbell Camera', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (259, 94, N'Smart Thermostat', CAST(55616.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (260, 95, N'Security Camera Indoor', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (261, 96, N'Smart Lock Keyless', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (262, 97, N'Motion Sensor Smart', CAST(10811.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (263, 98, N'Smart LED Strip 16ft', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (264, 99, N'WiFi Range Extender', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (265, 100, N'Smart Smoke Detector', CAST(27806.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (266, 101, N'Robot Vacuum Cleaner', CAST(92696.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (267, 102, N'Smart Air Purifier', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (268, 103, N'Smart Garage Door Opener', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (269, 104, N'Video Baby Monitor', CAST(37076.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (270, 105, N'Smart Blinds Controller', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (271, 106, N'Water Leak Detector Smart', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (272, 107, N'Smart Power Strip', CAST(13901.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (273, 108, N'Outdoor Security Camera', CAST(30896.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (274, 109, N'Smart Doorbell Chime', CAST(9266.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (275, 110, N'Humidity Monitor Smart', CAST(10811.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (276, 111, N'Smart Fan Controller', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (277, 112, N'Pet Camera with Treat', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (278, 113, N'Smart Water Valve', CAST(27806.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (279, 114, N'WiFi Router Mesh System', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (280, 115, N'Smart Mirror Display', CAST(123596.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (281, 116, N'Door Window Sensor Kit', CAST(13901.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (282, 117, N'Smart Sprinkler Controller', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (283, 118, N'Air Quality Monitor', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (284, 119, N'Smart Button Controller', CAST(7721.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (285, 120, N'Universal Remote Control', CAST(18536.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (286, 121, N'External SSD 1TB', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (287, 122, N'USB Hub 7-Port', CAST(10811.91 AS Decimal(18, 2)), 78, 10, CAST(N'2026-02-19T21:52:03.417' AS DateTime)),
        (288, 123, N'Portable Monitor 15.6 inch', CAST(61796.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (289, 124, N'Docking Station USB-C', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (290, 125, N'Wireless Keyboard Mouse Combo', CAST(18536.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (291, 126, N'RAM 16GB DDR4', CAST(24716.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (292, 127, N'Graphics Card GTX', CAST(154496.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (293, 128, N'CPU Cooler RGB', CAST(27806.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (294, 129, N'Gaming Chair Ergonomic', CAST(77246.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (295, 130, N'Desk Mat Extended', CAST(9266.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (296, 131, N'Monitor 27 inch 4K', CAST(123596.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (297, 132, N'NVMe SSD 500GB', CAST(27806.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (298, 133, N'Thunderbolt Cable 2m', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (299, 134, N'KVM Switch 2 Port', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (300, 135, N'Headphone Stand RGB', CAST(10811.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (301, 136, N'Cable Sleeve Kit', CAST(6176.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (302, 137, N'Vertical GPU Mount', CAST(13901.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (303, 138, N'PC Case ATX RGB', CAST(30896.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (304, 139, N'Power Supply 750W', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (305, 140, N'Motherboard B550', CAST(55616.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (306, 141, N'WiFi Card PCIe', CAST(13901.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (307, 142, N'Sound Card USB External', CAST(18536.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (308, 143, N'Capture Card HDMI', CAST(46346.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (309, 144, N'Streaming Deck Control', CAST(40166.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (310, 145, N'Desk Lamp LED Monitor', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (311, 146, N'Ergonomic Mouse Vertical', CAST(12356.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (312, 147, N'Wrist Rest Keyboard', CAST(7721.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (313, 148, N'Monitor Privacy Screen', CAST(15446.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (314, 149, N'Cable Clips 50 Pack', CAST(4013.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime)),
        (315, 150, N'Anti-Static Wrist Strap', CAST(3086.91 AS Decimal(18, 2)), 80, 10, CAST(N'2026-02-17T03:57:11.920' AS DateTime));
    SET IDENTITY_INSERT dbo.Inventory OFF;
END
GO

/* ===================================================================
   GadgetCentralDB
   =================================================================== */
IF DB_ID(N'GadgetCentralDB') IS NULL CREATE DATABASE [GadgetCentralDB];
GO
USE [GadgetCentralDB];
GO

IF OBJECT_ID(N'dbo.Inventory', N'U') IS NULL
CREATE TABLE dbo.Inventory (
    InventoryId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Inventory PRIMARY KEY,
    ProductId     INT            NOT NULL,
    ProductName   NVARCHAR(200)  NOT NULL,
    UnitPrice     DECIMAL(18,2)  NOT NULL,
    StockQuantity INT            NOT NULL,
    ReorderLevel  INT            NOT NULL CONSTRAINT DF_Inventory_ReorderLevel DEFAULT 10,
    LastUpdated   DATETIME2      NOT NULL CONSTRAINT DF_Inventory_LastUpdated DEFAULT SYSUTCDATETIME()
);
GO


IF NOT EXISTS (SELECT 1 FROM dbo.Inventory)
BEGIN
    SET IDENTITY_INSERT dbo.Inventory ON;
    INSERT INTO dbo.Inventory (InventoryId, ProductId, ProductName, UnitPrice, StockQuantity, ReorderLevel, LastUpdated) VALUES
        (166, 1, N'Wireless Earbuds Pro', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (167, 2, N'Noise Cancelling Headphones', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (168, 3, N'Bluetooth Speaker Mini', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (169, 4, N'Studio Monitor Headphones', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (170, 5, N'Portable Bluetooth Speaker', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (171, 6, N'Gaming Headset RGB', CAST(38516.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (172, 7, N'True Wireless Earbuds', CAST(19256.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (173, 8, N'Soundbar 2.1 Channel', CAST(57776.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (174, 9, N'Wireless Over-Ear Headphones', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (175, 10, N'Compact Bluetooth Speaker', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (176, 11, N'Sports Wireless Earbuds', CAST(22466.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (177, 12, N'Premium Noise Cancelling Headphones', CAST(96296.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (178, 13, N'Portable PA Speaker', CAST(51356.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (179, 14, N'USB Condenser Microphone', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (180, 15, N'Wireless Karaoke Microphone', CAST(14762.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (181, 16, N'Hi-Fi Stereo Headphones', CAST(32096.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (182, 17, N'Waterproof Bluetooth Speaker', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (183, 18, N'DJ Headphones Professional', CAST(80246.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (184, 19, N'Portable CD Player Bluetooth', CAST(22466.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (185, 20, N'Wireless TV Headphones', CAST(35306.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (186, 21, N'Bone Conduction Headphones', CAST(44936.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (187, 22, N'Party Speaker with Lights', CAST(60986.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (188, 23, N'In-Ear Monitor Earbuds', CAST(38516.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (189, 24, N'Vintage Bluetooth Speaker', CAST(32096.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (190, 25, N'Gaming Earbuds Low Latency', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (191, 26, N'Wireless Headphones for Kids', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (192, 27, N'Outdoor Rugged Speaker', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (193, 28, N'Audiophile Wired Headphones', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (194, 29, N'Mini Clip Speaker', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (195, 30, N'Smart Speaker Voice Assistant', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (196, 31, N'Smart Watch Fitness Tracker', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (197, 32, N'Fitness Band Heart Rate', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (198, 33, N'Smart Watch Pro GPS', CAST(96296.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (199, 34, N'Kids Smart Watch GPS', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (200, 35, N'Fitness Tracker Waterproof', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (201, 36, N'Smart Watch Touchscreen', CAST(51356.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (202, 37, N'Running Watch GPS', CAST(57776.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (203, 38, N'Health Monitoring Smart Band', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (204, 39, N'Luxury Smart Watch', CAST(128396.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (205, 40, N'Sports Smart Watch', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (206, 41, N'Sleep Tracker Band', CAST(22466.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (207, 42, N'Smart Watch Women Edition', CAST(73826.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (208, 43, N'Outdoor Adventure Watch', CAST(80246.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (209, 44, N'Smart Ring Fitness', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (210, 45, N'Blood Pressure Monitor Watch', CAST(51356.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (211, 46, N'Smart Watch for Seniors', CAST(38516.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (212, 47, N'Diving Smart Watch', CAST(96296.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (213, 48, N'Fashion Smart Watch', CAST(60986.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (214, 49, N'ECG Monitor Smart Watch', CAST(89876.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (215, 50, N'Budget Fitness Tracker', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (216, 51, N'Premium Health Watch', CAST(144446.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (217, 52, N'Smart Glasses AR', CAST(192596.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (218, 53, N'Posture Corrector Smart', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (219, 54, N'Smart Jewelry Bracelet', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (220, 55, N'Cycling Computer Watch', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (221, 56, N'Golf GPS Watch', CAST(80246.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (222, 57, N'Meditation Band Biofeedback', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (223, 58, N'Smart Clip Fitness Tracker', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (224, 59, N'Hybrid Smart Watch', CAST(57776.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (225, 60, N'Temperature Monitoring Band', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (226, 61, N'Portable Charger 10000mAh', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (227, 62, N'Wireless Charging Pad', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (228, 63, N'USB-C Hub Multiport', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (229, 64, N'Power Bank 20000mAh', CAST(19256.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (230, 65, N'Fast Wireless Charger', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (231, 66, N'Cable Organizer Kit', CAST(6416.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (232, 67, N'Phone Stand Adjustable', CAST(8021.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (233, 68, N'Laptop Stand Aluminum', CAST(14441.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (234, 69, N'Screen Protector Kit', CAST(4811.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (235, 70, N'Phone Case Protective', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (236, 71, N'Car Mount Phone Holder', CAST(6416.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (237, 72, N'Selfie Stick Bluetooth', CAST(8021.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (238, 73, N'Ring Light for Video', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (239, 74, N'Webcam HD 1080p', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (240, 75, N'USB Flash Drive 128GB', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (241, 76, N'SD Card 256GB', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (242, 77, N'Cable Management Box', CAST(8021.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (243, 78, N'Wireless Mouse Ergonomic', CAST(11231.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (244, 79, N'Mechanical Keyboard RGB', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (245, 80, N'Monitor Arm Dual', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (246, 81, N'Laptop Cooling Pad', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (247, 82, N'Drawing Tablet Graphics', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (248, 83, N'Stylus Pen Precision', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (249, 84, N'VR Headset Stand', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (250, 85, N'Gaming Mouse Pad XXL', CAST(8021.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (251, 86, N'Cable Tester Multimeter', CAST(11231.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (252, 87, N'Phone Grip Ring Holder', CAST(3206.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (253, 88, N'Laptop Sleeve 15 inch', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (254, 89, N'Desk Organizer Tech', CAST(11231.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (255, 90, N'Blue Light Blocking Glasses', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (256, 91, N'Smart Light Bulb RGB', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (257, 92, N'Smart Plug WiFi', CAST(6416.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (258, 93, N'Video Doorbell Camera', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (259, 94, N'Smart Thermostat', CAST(57776.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (260, 95, N'Security Camera Indoor', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (261, 96, N'Smart Lock Keyless', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (262, 97, N'Motion Sensor Smart', CAST(11231.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (263, 98, N'Smart LED Strip 16ft', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (264, 99, N'WiFi Range Extender', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (265, 100, N'Smart Smoke Detector', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (266, 101, N'Robot Vacuum Cleaner', CAST(96296.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (267, 102, N'Smart Air Purifier', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (268, 103, N'Smart Garage Door Opener', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (269, 104, N'Video Baby Monitor', CAST(38516.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (270, 105, N'Smart Blinds Controller', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (271, 106, N'Water Leak Detector Smart', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (272, 107, N'Smart Power Strip', CAST(14441.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (273, 108, N'Outdoor Security Camera', CAST(32096.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (274, 109, N'Smart Doorbell Chime', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (275, 110, N'Humidity Monitor Smart', CAST(11231.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (276, 111, N'Smart Fan Controller', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (277, 112, N'Pet Camera with Treat', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (278, 113, N'Smart Water Valve', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (279, 114, N'WiFi Router Mesh System', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (280, 115, N'Smart Mirror Display', CAST(128396.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (281, 116, N'Door Window Sensor Kit', CAST(14441.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (282, 117, N'Smart Sprinkler Controller', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (283, 118, N'Air Quality Monitor', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (284, 119, N'Smart Button Controller', CAST(8021.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (285, 120, N'Universal Remote Control', CAST(19256.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (286, 121, N'External SSD 1TB', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (287, 122, N'USB Hub 7-Port', CAST(11231.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (288, 123, N'Portable Monitor 15.6 inch', CAST(64196.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (289, 124, N'Docking Station USB-C', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (290, 125, N'Wireless Keyboard Mouse Combo', CAST(19256.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (291, 126, N'RAM 16GB DDR4', CAST(25676.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (292, 127, N'Graphics Card GTX', CAST(160496.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (293, 128, N'CPU Cooler RGB', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (294, 129, N'Gaming Chair Ergonomic', CAST(80246.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (295, 130, N'Desk Mat Extended', CAST(9626.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (296, 131, N'Monitor 27 inch 4K', CAST(128396.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (297, 132, N'NVMe SSD 500GB', CAST(28886.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (298, 133, N'Thunderbolt Cable 2m', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (299, 134, N'KVM Switch 2 Port', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (300, 135, N'Headphone Stand RGB', CAST(11231.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (301, 136, N'Cable Sleeve Kit', CAST(6416.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (302, 137, N'Vertical GPU Mount', CAST(14441.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (303, 138, N'PC Case ATX RGB', CAST(32096.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (304, 139, N'Power Supply 750W', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (305, 140, N'Motherboard B550', CAST(57776.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (306, 141, N'WiFi Card PCIe', CAST(14441.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (307, 142, N'Sound Card USB External', CAST(19256.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (308, 143, N'Capture Card HDMI', CAST(48146.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (309, 144, N'Streaming Deck Control', CAST(41726.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (310, 145, N'Desk Lamp LED Monitor', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (311, 146, N'Ergonomic Mouse Vertical', CAST(12836.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (312, 147, N'Wrist Rest Keyboard', CAST(8021.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (313, 148, N'Monitor Privacy Screen', CAST(16046.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (314, 149, N'Cable Clips 50 Pack', CAST(4169.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime)),
        (315, 150, N'Anti-Static Wrist Strap', CAST(3206.79 AS Decimal(18, 2)), 100, 10, CAST(N'2026-02-17T03:57:11.953' AS DateTime));
    SET IDENTITY_INSERT dbo.Inventory OFF;
END
GO
