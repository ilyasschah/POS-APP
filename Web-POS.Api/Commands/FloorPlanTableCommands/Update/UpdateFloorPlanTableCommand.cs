using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.FloorPlanTableCommands.Update
{
    public class UpdateFloorPlanTableCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public UpdateFloorPlanTableRequest Request { get; set; }

        public class UpdateFloorPlanTableCommandHandler : IRequestHandler<UpdateFloorPlanTableCommand, bool>
        {
            private readonly FloorPlanTableService _service;

            public UpdateFloorPlanTableCommandHandler(FloorPlanTableService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateFloorPlanTableCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdateFloorPlanTableCommandValidator : AbstractValidator<UpdateFloorPlanTableCommand>
        {
            public UpdateFloorPlanTableCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty();
                RuleFor(c => c.Request.Width).GreaterThan(0);
                RuleFor(c => c.Request.Height).GreaterThan(0);
            }
        }
    }
}