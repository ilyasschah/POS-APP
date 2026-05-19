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
            [FromQuery] int? productGroupId = null)
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
            });

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
            [FromQuery] bool includeSubgroups = false)
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
            });

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
            [FromQuery] int? productGroupId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PaymentTypesByCustomerDto>>> GetPaymentTypesByCustomer(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PaymentTypesByUserDto>>> GetPaymentTypesByUser(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByPaymentTypeDto>>> GetSalesByPaymentType(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null)
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
            });

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
            [FromQuery] int? productGroupId = null)
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
            });

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
            [FromQuery] int? productGroupId = null)
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
            });

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
            [FromQuery] int? productGroupId = null)
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
            });

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
            [FromQuery] int? productGroupId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<UnpaidSalesDto>>> GetUnpaidSales(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<HourlySalesByGroupDto>>> GetHourlySalesByGroup(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? productGroupId = null,
            [FromQuery] int? warehouseId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<SalesByTableDto>>> GetSalesByTable(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<HourlySalesDto>>> GetHourlySales(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? warehouseId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<DailySalesDto>>> GetDailySales(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null)
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
            });

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<InvoiceListDto>>> GetInvoiceList(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? customerId = null,
            [FromQuery] int? userId = null,
            [FromQuery] int? warehouseId = null)
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
            });

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
            [FromQuery] int? productGroupId = null)
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
            });

            return Ok(result);
        }
    }
}
