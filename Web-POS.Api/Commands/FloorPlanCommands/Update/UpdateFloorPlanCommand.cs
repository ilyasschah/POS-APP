using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.FloorPlanCommands.Update
{
    public class UpdateFloorPlanCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public UpdateFloorPlanRequest Request { get; set; }

        public class UpdateFloorPlanCommandHandler : IRequestHandler<UpdateFloorPlanCommand, bool>
        {
            private readonly FloorPlanService _service;

            public UpdateFloorPlanCommandHandler(FloorPlanService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateFloorPlanCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdateFloorPlanCommandValidator : AbstractValidator<UpdateFloorPlanCommand>
        {
            public UpdateFloorPlanCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty();
            }
        }
    }
}