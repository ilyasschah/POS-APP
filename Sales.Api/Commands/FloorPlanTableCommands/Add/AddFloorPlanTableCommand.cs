using FluentValidation;
using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.FloorPlanTableCommands.Add
{
    public class AddFloorPlanTableCommand : IRequest<FloorPlanTableDto>
    {
        public CreateFloorPlanTableRequest Request { get; set; }

        public class AddFloorPlanTableCommandHandler : IRequestHandler<AddFloorPlanTableCommand, FloorPlanTableDto>
        {
            private readonly FloorPlanTableService _service;

            public AddFloorPlanTableCommandHandler(FloorPlanTableService service)
            {
                _service = service;
            }

            public async Task<FloorPlanTableDto> Handle(AddFloorPlanTableCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return MapperFloorPlanTable.MapToFloorPlanTableDto(newEntity);
            }
        }

        public class AddFloorPlanTableCommandValidator : AbstractValidator<AddFloorPlanTableCommand>
        {
            public AddFloorPlanTableCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty();
                RuleFor(c => c.Request.FloorPlanId).GreaterThan(0);
                RuleFor(c => c.Request.Width).GreaterThan(0);
                RuleFor(c => c.Request.Height).GreaterThan(0);
            }
        }
    }
}