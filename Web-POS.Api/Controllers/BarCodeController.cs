using Api.Commands.BarcodeCommands.Add;
using Api.Commands.BarcodeCommands.Delete;
using Api.Commands.BarcodeCommands.Update;
using Api.Models;
using Api.Queries.BarcodesQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class BarcodesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<BarcodeDto>>> GetAllBarCodeProductName([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            return Ok(await mediator.Send(new GetAllBarCodeProductNameQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<BarcodeDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            var result = await mediator.Send(new GetBarcodeByIdQuery(id, companyId));
            return result == null ? NotFound(new { message = "Barcode not found" }) : Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<BarcodeDto>>> GetByProductId([FromQuery] int productId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (productId <= 0) return BadRequest(new { message = "Product ID is required" });

            var result = await mediator.Send(new GetBarcodesByProductIdQuery { ProductId = productId, CompanyId = companyId });
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromBody] CreateBarcodeRequest createRequest, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            try
            {
                var result = await mediator.Send(new AddBarcodecommand(createRequest, companyId));
                return Ok(new
                {
                    message = $"The barcode '{result.Value}' has been assigned to product '{result.ProductName}'",
                    data = result
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateBarcodeRequest updateRequest, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            try
            {
                var result = await mediator.Send(new UpdateBarcodecommand(updateRequest, companyId));
                return Ok(new { message = $"The barcode '{result.Value}' has been updated for product '{result.ProductName}'" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (id <= 0) return BadRequest(new { message = "Barcode ID is required" });

            try
            {
                var result = await mediator.Send(new DeleteBarcodeByIdCommand(id, companyId));
                return result
                    ? Ok(new { message = "Barcode deleted successfully" })
                    : NotFound(new { message = "Barcode not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}