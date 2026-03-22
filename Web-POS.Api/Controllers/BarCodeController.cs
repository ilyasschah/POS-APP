using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.BarcodesCommands.Add;
using Api.Commands.BarcodesCommands.Delete;
using Api.Commands.BarcodesCommands.Update;
using Api.Queries.BarCodesQuery.Get;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class BarcodesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<BarcodeDto>>> GetAllBarCodeProductName([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllBarCodeProductNameQuery { CompanyId = companyId }));
        }
        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<BarcodeDto>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetBarcodeByIdQuery(id, companyId)));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<BarcodeDto>> Add([FromBody] CreateBarcodeRequest createrequest, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var command = new AddBarcodecommand(createrequest, companyId);
            var result = await mediator.Send(command);
            return Ok(new
            {
                message = $"The barcode {result.Value} has been assigned to product name {result.ProductName}"
            });
        }
        [HttpPatch("[action]")]
        public async Task<ActionResult<BarcodeDto>> Update([FromBody] UpdateBarcodeRequest updaterequest, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new UpdateBarcodecommand(updaterequest, companyId);
            var result = await mediator.Send(command);
            return Ok(new
            { message = $"The barcode {result.Value} has been updated to product name {result.ProductName}" }
            );
        }
        [HttpDelete("[action]")]
        public async Task<ActionResult<bool>> Delete(DeleteBarcodeRequest deleterequest,[FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new DeleteBarcodeByIdCommand(deleterequest, companyId);
            var result = await mediator.Send(command);
            return result;
        }
    }
}
