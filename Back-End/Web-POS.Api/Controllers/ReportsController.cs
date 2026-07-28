using Api.Models;
using Api.Queries.ReportQueries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ReportsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByProductDto>>> GetSalesByProduct(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetSalesByProductQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                CustomerId     = customerId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByProductGroupDto>>> GetSalesByProductGroup(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null,
            [FromQuery] bool includeSubgroups = false, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetSalesByProductGroupQuery
            {
                CompanyId       = companyId,
                StartDate       = startDate,
                EndDate         = endDate,
                CustomerId      = customerId,
                UserId          = userId,
                WarehouseId     = warehouseId,
                ProductId       = productId,
                ProductGroupId  = productGroupId,
                IncludeSubgroups = includeSubgroups,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByCustomerDto>>> GetSalesByCustomer(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetSalesByCustomerQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                CustomerId     = customerId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PaymentTypesByCustomerDto>>> GetPaymentTypesByCustomer(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPaymentTypesByCustomerQuery
            {
                CompanyId   = companyId,
                StartDate   = startDate,
                EndDate     = endDate,
                CustomerId  = customerId,
                UserId      = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PaymentTypesByUserDto>>> GetPaymentTypesByUser(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPaymentTypesByUserQuery
            {
                CompanyId   = companyId,
                StartDate   = startDate,
                EndDate     = endDate,
                CustomerId  = customerId,
                UserId      = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByPaymentTypeDto>>> GetSalesByPaymentType(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetSalesByPaymentTypeQuery
            {
                CompanyId  = companyId,
                StartDate  = startDate,
                EndDate    = endDate,
                CustomerId = customerId,
                UserId     = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesItemListDto>>> GetSalesItemList(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetSalesItemListQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                CustomerId     = customerId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByUserDto>>> GetSalesByUser(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetSalesByUserQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                CustomerId     = customerId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<RefundItemListDto>>> GetRefundItemList(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetRefundItemListQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                CustomerId     = customerId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProfitDto>>> GetProfit(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetProfitQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                CustomerId     = customerId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<UnpaidSalesDto>>> GetUnpaidSales(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetUnpaidSalesQuery
            {
                CompanyId   = companyId,
                StartDate   = startDate,
                EndDate     = endDate,
                CustomerId  = customerId,
                UserId      = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<HourlySalesByGroupDto>>> GetHourlySalesByGroup(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? productGroupId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetHourlySalesByGroupQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                CustomerId     = customerId,
                ProductGroupId = productGroupId,
                WarehouseId    = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByTableDto>>> GetSalesByTable(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetSalesByTableQuery
            {
                CompanyId   = companyId,
                StartDate   = startDate,
                EndDate     = endDate,
                CustomerId  = customerId,
                UserId      = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<HourlySalesDto>>> GetHourlySales(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetHourlySalesQuery
            {
                CompanyId   = companyId,
                StartDate   = startDate,
                EndDate     = endDate,
                CustomerId  = customerId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<DailySalesDto>>> GetDailySales(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetDailySalesQuery
            {
                CompanyId   = companyId,
                StartDate   = startDate,
                EndDate     = endDate,
                CustomerId  = customerId,
                UserId      = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<InvoiceListDto>>> GetInvoiceList(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetInvoiceListQuery
            {
                CompanyId   = companyId,
                StartDate   = startDate,
                EndDate     = endDate,
                CustomerId  = customerId,
                UserId      = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<StockMovementDto>>> GetStockMovement(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? userId = null,
            [FromQuery] int? productId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetStockMovementQuery
            {
                CompanyId = companyId,
                StartDate = startDate,
                EndDate   = endDate,
                UserId    = userId,
                ProductId = productId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ItemsDiscountsDto>>> GetItemsDiscounts(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? productId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetItemsDiscountsQuery
            {
                CompanyId  = companyId,
                StartDate  = startDate,
                EndDate    = endDate,
                CustomerId = customerId,
                UserId     = userId,
                ProductId  = productId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<DiscountsGrantedDto>>> GetDiscountsGranted(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetDiscountsGrantedQuery
            {
                CompanyId  = companyId,
                StartDate  = startDate,
                EndDate    = endDate,
                CustomerId = customerId,
                UserId     = userId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PurchaseByProductDto>>> GetPurchaseByProduct(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPurchaseByProductQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                SupplierId     = supplierId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<UnpaidPurchaseDto>>> GetUnpaidPurchase(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetUnpaidPurchaseQuery
            {
                CompanyId   = companyId,
                StartDate   = startDate,
                EndDate     = endDate,
                SupplierId  = supplierId,
                UserId      = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PurchaseBySupplierDto>>> GetPurchaseBySupplier(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPurchaseBySupplierQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                SupplierId     = supplierId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PurchaseDiscountsDto>>> GetPurchaseDiscounts(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? userId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPurchaseDiscountsQuery
            {
                CompanyId  = companyId,
                StartDate  = startDate,
                EndDate    = endDate,
                SupplierId = supplierId,
                UserId     = userId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PurchaseByTaxDto>>> GetPurchaseByTax(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPurchaseByTaxQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                SupplierId     = supplierId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PurchaseInvoiceListDto>>> GetPurchaseInvoiceList(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPurchaseInvoiceListQuery
            {
                CompanyId  = companyId,
                StartDate  = startDate,
                EndDate    = endDate,
                SupplierId = supplierId,
                UserId     = userId,
                WarehouseId = warehouseId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PurchaseItemsDiscountsDto>>> GetPurchaseItemsDiscounts(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? productId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPurchaseItemsDiscountsQuery
            {
                CompanyId  = companyId,
                StartDate  = startDate,
                EndDate    = endDate,
                SupplierId = supplierId,
                UserId     = userId,
                ProductId  = productId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByTaxDto>>> GetSalesByTax(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetSalesByTaxQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                CustomerId     = customerId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PurchaseExpirationDateDto>>> GetPurchaseExpirationDate(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetPurchaseExpirationDateQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                SupplierId     = supplierId,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<StockReturnByProductDto>>> GetStockReturnByProduct(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetStockReturnByProductQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<LossAndDamageByProductDto>>> GetLossAndDamageByProduct(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null,
            [FromQuery] int? productId = null,
            [FromQuery] int? productGroupId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetLossAndDamageByProductQuery
            {
                CompanyId      = companyId,
                StartDate      = startDate,
                EndDate        = endDate,
                UserId         = userId,
                WarehouseId    = warehouseId,
                ProductId      = productId,
                ProductGroupId = productGroupId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ReorderProductListDto>>> GetReorderProductList(
            [FromQuery] int companyId,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? productId  = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var result = await mediator.Send(new GetReorderProductListQuery
            {
                CompanyId  = companyId,
                SupplierId = supplierId,
                ProductId  = productId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<LowStockWarningDto>>> GetLowStockWarning(
            [FromQuery] int companyId,
            [FromQuery] int? supplierId = null,
            [FromQuery] int? productId  = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var result = await mediator.Send(new GetLowStockWarningQuery
            {
                CompanyId  = companyId,
                SupplierId = supplierId,
                ProductId  = productId,
            }, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<TransactionHistoryDto>>> GetTransactionHistory(
            [FromQuery] int companyId,
            [FromQuery] int partnerId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (partnerId == 0) return BadRequest("Partner ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetTransactionHistoryQuery
            {
                CompanyId = companyId,
                PartnerId = partnerId,
                StartDate = startDate,
                EndDate   = endDate,
            }, ct);

            return Ok(result);
        }
    }
}
